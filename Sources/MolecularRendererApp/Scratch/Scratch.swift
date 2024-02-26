// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [[Entity]] {
  // Demonstrate transmission of a clock signal in one of the 2 available
  // directions. It should demonstrate the sequence of clock phases expected in
  // the full ALU. Measure how short the switching time can be.
  // - Take at least one screenshot to document this experiment.
  
  var system = System()
  system.minimize()
  system.initializeRigidBodies()
  
  // Set up the system for simulation.
  for rodID in system.rods.indices {
    system.rods[rodID].rigidBody!.centerOfMass += SIMD3(0, 0, -0.5)
  }
  
  // Start with a short rigid body dynamics simulation, with the housing and
  // drive wall positionally constrained. Test whether the rods fall into their
  // lowest-energy state.
  var rigidBodies: [MM4RigidBody] = []
  rigidBodies.append(system.housing.rigidBody!)
  for rod in system.rods {
    rigidBodies.append(rod.rigidBody!)
  }
  rigidBodies.append(system.driveWall.rigidBody!)
  
  var emptyParamsDesc = MM4ParametersDescriptor()
  emptyParamsDesc.atomicNumbers = []
  emptyParamsDesc.bonds = []
  var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
  for rigidBody in rigidBodies {
    systemParameters.append(contentsOf: rigidBody.parameters)
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = systemParameters
  forceFieldDesc.cutoffDistance = 2
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  
  func createFrame(rigidBodies: [MM4RigidBody]) -> [Entity] {
    var output: [Entity] = []
    for rigidBody in rigidBodies {
      for atomID in rigidBody.parameters.atoms.indices {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let storage = SIMD4(position, Float(atomicNumber))
        let entity = Entity(storage: storage)
        output.append(entity)
      }
    }
    return output
  }
  
  let ΔtMin: Double = 0.002
  let ΔtStart: Double = 0.040
  let ΔtMax: Double = 0.400
  var Δt: Double = ΔtStart
  var NP0: Int = 0
  var oldRigidBodies: [MM4RigidBody]?
  
  // Demonstrate rigid body energy minimization with FIRE. This is a proof of
  // concept for the DFT simulator. Use INQ as a reference, then incorporate the
  // improvements from FIRE 2.0 and ABC.
  var frames: [[Entity]] = []
  frames.append(createFrame(rigidBodies: rigidBodies))
  for frameID in 0..<5000 {
    // Record which frame this is.
    forceField.positions = rigidBodies.flatMap(\.positions)
    if frameID % 10 == 0 {
      print("frame: \(frameID)")
    }
    
    // Assign forces.
    let forces = forceField.forces
    var cursor = 0
    for rigidBodyID in rigidBodies.indices {
      let spacing = rigidBodies[rigidBodyID].parameters.atoms.count
      let range = cursor..<(cursor + spacing)
      cursor += spacing
      rigidBodies[rigidBodyID].forces = Array(forces[range])
    }
    
    // Calculate P <- F * v.
    var P: Double = .zero
    for rigidBody in rigidBodies {
      let v = rigidBody.linearMomentum / rigidBody.mass
      let w = rigidBody.angularMomentum / rigidBody.momentOfInertia
      P += (rigidBody.netForce! * v).sum()
      P += (rigidBody.netTorque! * w).sum()
    }
    
    // Save the forces, as they'll become 'nil' when the position resets.
    let netForces = rigidBodies.map { $0.netForce! }
    let netTorques = rigidBodies.map { $0.netTorque! }
    let maxForce = netForces[1...4].map {
      ($0 * $0).sum().squareRoot()
    }.max()!
    let maxTorque = netTorques[1...4].map {
      ($0 * $0).sum().squareRoot()
    }.max()!
    if maxForce < 1 && maxTorque < 1 {
      print("converged after \(frameID) iterations")
      break
    }
    
    // Branch on the value of P.
    if P < 0 {
      print("restart")
      if let oldRigidBodies {
        // FIRE 2.0 correction.
        rigidBodies = oldRigidBodies
      } else {
        for rigidBodyID in rigidBodies.indices {
          rigidBodies[rigidBodyID].linearMomentum = .zero
          rigidBodies[rigidBodyID].angularMomentum = .zero
        }
      }
      
      NP0 = 0
      Δt = max(Δt * 0.5, ΔtMin)
    } else {
      NP0 += 1
      if NP0 > 5 {
        Δt = min(Δt * 1.1, ΔtMax)
      }
    }
    
    
    // Perform MD integration.
    oldRigidBodies = []
    for rigidBodyID in rigidBodies.indices {
      var copy = rigidBodies[rigidBodyID]
      defer {
        rigidBodies[rigidBodyID] = copy
      }
      
      var v = copy.linearMomentum / copy.mass
      var w = copy.angularMomentum / copy.momentOfInertia
      let f = netForces[rigidBodyID]
      let τ = netTorques[rigidBodyID]
      
      let vNorm = (v * v).sum().squareRoot()
      let fNorm = (f * f).sum().squareRoot()
      var forceScale = vNorm / fNorm
      if forceScale.isNaN || forceScale.isInfinite {
        forceScale = .zero
      }
      
      let wNorm = (w * w).sum().squareRoot()
      let τNorm = (τ * τ).sum().squareRoot()
      var torqueScale = wNorm / τNorm
      if torqueScale.isNaN || torqueScale.isInfinite {
        torqueScale = .zero
      }
      
      // Semi-implicit Euler integration.
      let α: Double = 0.25
      v += Δt * f / copy.mass
      w += Δt * τ / copy.momentOfInertia
      v = (1 - α) * v + α * f * forceScale
      w = (1 - α) * w + α * τ * torqueScale
      
      // Accelerated bias correction.
      if NP0 > 0 {
        var biasCorrection = 1 - α
        biasCorrection = Double.pow(biasCorrection, Double(NP0))
        biasCorrection = 1 / (1 - biasCorrection)
        v *= biasCorrection
        w *= biasCorrection
      }
      
      // Regular MD integration.
      copy.linearMomentum = v * copy.mass
      copy.angularMomentum = w * copy.momentOfInertia
      if rigidBodyID == 0 || rigidBodyID == 5 {
        copy.linearMomentum = .zero
        copy.angularMomentum = .zero
      }
      let linearVelocity = copy.linearMomentum / copy.mass
      let angularVelocity = copy.angularMomentum / copy.momentOfInertia
      let angularSpeed = (angularVelocity * angularVelocity).sum().squareRoot()
      copy.centerOfMass += Δt * linearVelocity
      copy.rotate(angle: Δt * angularSpeed)
      
      // Save the rigid bodies for the next iteration at this checkpoint.
      var oldRigidBody = rigidBodies[rigidBodyID]
      oldRigidBody.linearMomentum = copy.linearMomentum
      oldRigidBody.angularMomentum = copy.angularMomentum
      oldRigidBody.centerOfMass += 0.5 * Δt * linearVelocity
      oldRigidBody.rotate(angle: 0.5 * Δt * angularSpeed)
      oldRigidBody.linearMomentum = .zero
      oldRigidBody.angularMomentum = .zero
      oldRigidBodies!.append(oldRigidBody)
    }
    
    // Display the current positions.
    frames.append(createFrame(rigidBodies: rigidBodies))
  }
  
  return frames
}
