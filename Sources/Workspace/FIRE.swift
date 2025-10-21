//
//  FIRE.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 5/31/24.
//

import HDL
import Numerics

struct FIREMinimizationDescriptor {
  /// Optional. Indices of atoms to keep positionally constrained.
  var anchors: Set<UInt32>?
  
  /// Required. The tolerance for maximum force among the atoms.
  ///
  /// The default value is 10 pN. This value is sufficient for accurate
  /// structures. For accurate energies (when comparing two different
  /// structures), choose a value of 0.3 pN.
  var forceTolerance: Float = 10
  
  /// Required. The mass of each atom (in yoctograms).
  var masses: [Float]?
  
  /// Required. The position of each atom's nucleus.
  var positions: [SIMD3<Float>]?
  
  /// Required. The minimum timestep.
  var ΔtMin: Float = 0.25e-3
  
  /// Required. The inital timestep.
  var ΔtStart: Float = 0.001
  
  /// Required. The maximum timestep.
  var ΔtMax: Float = 0.010
}

/// A data structure for integration during an energy minimization.
///
/// This is not a full molecular dynamics engine. The current prototype is only
/// scoped to something capable of ONIOM simulation.
struct FIREMinimization {
  // Integrator settings.
  let anchors: Set<UInt32>
  let masses: [Float]
  let ΔtMin: Float
  let ΔtMax: Float
  let forceTolerance: Float
  
  // FIRE timestep trackers.
  private(set) var Δt: Float
  private(set) var NP0: Int
  
  // Dynamical variables.
  private(set) var time: Double
  var positions: [SIMD3<Float>] // must be mutable to enforce constraints
  var velocities: [SIMD3<Float>] // must be mutable to enforce constraints
  
  // Cached state.
  private(set) var oldTime: Double
  private(set) var oldPositions: [SIMD3<Float>]
  
  init(descriptor: FIREMinimizationDescriptor) {
    guard let masses = descriptor.masses,
          let positions = descriptor.positions else {
      fatalError("Descriptor was incomplete.")
    }
    guard masses.count == positions.count else {
      fatalError("Size of masses did not match size of positions.")
    }
    
    // Initialize the constraints.
    if let anchors = descriptor.anchors {
      self.anchors = anchors
    } else {
      self.anchors = []
    }
    self.masses = masses
    ΔtMin = descriptor.ΔtMin
    ΔtMax = descriptor.ΔtMax
    forceTolerance = descriptor.forceTolerance
    
    // Initialize the timestep trackers.
    Δt = descriptor.ΔtStart
    NP0 = 0
    
    // Initialize the dynamical variables.
    time = 0
    self.positions = positions
    velocities = [SIMD3<Float>](repeating: .zero, count: positions.count)
    
    // Initialize the cached state.
    oldTime = 0
    oldPositions = positions
  }
  
  // If the minimization has converged, return `true`. Otherwise, integrate for
  // one timestep.
  mutating func step(forces: [SIMD3<Float>]) -> Bool {
    guard forces.count == positions.count else {
      fatalError("Size of forces did not match size of positions.")
    }
    
    // Find the power (P) and maximum force.
    var P: Double = .zero
    var maxForce: Float = .zero
    for atomID in positions.indices {
      if anchors.contains(UInt32(atomID)) {
        continue
      }
      let force = forces[atomID]
      let velocity = velocities[atomID]
      P += Double((force * velocity).sum())
      
      let forceMagnitude = (force * force).sum().squareRoot()
      maxForce = max(maxForce, forceMagnitude)
    }
    
    // Return early if converged.
    if maxForce < forceTolerance {
      return true
    }
    
    // Prepare for integration.
    updateTimestep(P: P)
    
    // Integrate.
    integrate(forces: forces)
    oldTime = time + Double(0.5 * Δt)
    time = time + Double(Δt)
    
    // Return that you haven't converged.
    return false
  }
  
  // Adjust the timestep, according to the value of P.
  private mutating func updateTimestep(P: Double) {
    if time > 0, P < 0 {
      time = oldTime
      positions = oldPositions
      velocities = Array(repeating: .zero, count: positions.count)
      
      NP0 = 0
      Δt = max(0.5 * Δt, ΔtMin)
    } else {
      NP0 += 1
      if NP0 > 5 {
        Δt = min(1.1 * Δt, ΔtMax)
      }
    }
  }
  
  // Compute the force scale for the entire system.
  //
  // WARNING: This must be done after the velocities are reset when P < 0.
  private func createForceScale(forces: [SIMD3<Float>]) -> Float {
    var vAccumulator: Float = .zero
    var fAccumulator: Float = .zero
    for atomID in positions.indices {
      if anchors.contains(UInt32(atomID)) {
        continue
      }
      let velocity = velocities[atomID]
      let force = forces[atomID]
      vAccumulator += (velocity * velocity).sum()
      fAccumulator += (force * force).sum()
    }
    
    let vNorm = vAccumulator.squareRoot()
    let fNorm = fAccumulator.squareRoot()
    var forceScale = vNorm / fNorm
    if forceScale.isNaN || forceScale.isInfinite {
      forceScale = .zero
    }
    return forceScale
  }
  
  // Perform an integration step.
  private mutating func integrate(forces: [SIMD3<Float>]) {
    // Find the force scale for redirecting atom velocities.
    let forceScale = createForceScale(forces: forces)
    
    // Iterate over the atoms.
    for atomID in positions.indices {
      var halfwayPosition: SIMD3<Float>
      var finalPosition: SIMD3<Float>
      var finalVelocity: SIMD3<Float>
      defer {
        oldPositions[atomID] = halfwayPosition
        positions[atomID] = finalPosition
        velocities[atomID] = finalVelocity
      }
      
      let initialPosition = positions[atomID]
      let initialVelocity = velocities[atomID]
      if anchors.contains(UInt32(atomID)) {
        // Prevent the anchors from moving.
        halfwayPosition = initialPosition
        finalPosition = initialPosition
        finalVelocity = .zero
      } else {
        let force = forces[atomID]
        let mass = masses[atomID]
        var velocity = initialVelocity
        
        // Semi-implicit Euler integration.
        // - This could be considered a valid form of molecular dynamics, just
        //   with a forcing term that accelerates the descent into the global
        //   minimum.
        let α: Float = 0.25
        velocity += Δt * force / mass
        velocity = (1 - α) * velocity + α * force * forceScale
        
        // Accelerated bias correction.
        // - This should be applied whenever the system's velocities are
        //   suddenly reset to zero. Ideally, such a situation will never
        //   happen in a molecular dynamics simulation.
        // - The correction can shrink the number of iterations by a factor of
        //   2x.
        if NP0 > 0 {
          var biasCorrection = 1 - α
          biasCorrection = Float.pow(biasCorrection, Float(NP0))
          biasCorrection = 1 / (1 - biasCorrection)
          velocity *= biasCorrection
        }
        
        // Clamp the velocity to 4000 m/s.
        let speed = (velocity * velocity).sum().squareRoot()
        if speed > 4.0 {
          velocity *= 4.0 / speed
        }
        finalVelocity = velocity
        
        // Integrate the position.
        halfwayPosition = initialPosition + 0.5 * Δt * velocity
        finalPosition = initialPosition + Δt * velocity
      }
    }
  }
}
