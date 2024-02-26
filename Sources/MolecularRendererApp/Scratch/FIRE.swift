//
//  FIRE.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 2/26/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

struct FIREResult {
  /// The iteration ID where the minimization converged, if any.
  var convergedIterationID: Int?
  
  /// Frames for animating the minimization.
  var frames: [[Entity]] = []
}

struct FIRE {
  /// Optional. The rigid body indices to keep positionally constrained.
  var anchors: Set<UInt32> = []
  
  /// Required. The rigid bodies to minimize.
  var rigidBodies: [MM4RigidBody] = []
  
  /// Required. The minimum timestep.
  var ΔtMin: Double = 0.002
  
  /// Required. The default timestep.
  var ΔtStart: Double = 0.040
  
  /// Required. The maximum timestep.
  var ΔtMax: Double = 0.400
  
  /// Required. The maximum number of iterations.
  var maxIterations: Int = 1000
  
  /// Required. The force tolerance for convergence.
  var forceTolerance: Double = 1
  
  /// Required. The torque tolerance for convergence.
  var torqueTolerance: Double = 1
  
  init() {
    
  }
  
  private func createFrame() -> [Entity] {
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
  
  private func createForceField() -> MM4ForceField {
    var emptyParamsDesc = MM4ParametersDescriptor()
    emptyParamsDesc.atomicNumbers = []
    emptyParamsDesc.bonds = []
    var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
    for rigidBody in rigidBodies {
      systemParameters.append(contentsOf: rigidBody.parameters)
    }
    
    // This uses a cutoff distance of 2 nm for accurate vdW forces.
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = systemParameters
    forceFieldDesc.cutoffDistance = 2
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    return forceField
  }
  
  @discardableResult
  mutating func minimize() -> FIREResult {
    let forceField = createForceField()
    var result = FIREResult()
    
    var Δt: Double = ΔtStart
    var NP0: Int = 0
    var oldRigidBodies: [MM4RigidBody]?
    
    result.frames.append(createFrame())
    for frameID in 0..<maxIterations {
      // Record which frame this is.
      forceField.positions = rigidBodies.flatMap(\.positions)
      
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
      var maxForce: Double = .zero
      var maxTorque: Double = .zero
      for rigidBodyID in rigidBodies.indices {
        if anchors.contains(UInt32(rigidBodyID)) {
          continue
        }
        let force = netForces[rigidBodyID]
        let torque = netTorques[rigidBodyID]
        let normForce = (force * force).sum().squareRoot()
        let normTorque = (torque * torque).sum().squareRoot()
        maxForce = max(maxForce, normForce)
        maxTorque = max(maxTorque, normTorque)
      }
      
      if maxForce < 1 && maxTorque < 1 {
        result.convergedIterationID = frameID
        break
      }
      
      // Branch on the value of P.
      if P < 0 {
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
        if anchors.contains(UInt32(rigidBodyID)) {
          copy.linearMomentum = .zero
          copy.angularMomentum = .zero
        }
        let linearVelocity = copy.linearMomentum / copy.mass
        let angularVelocity = copy.angularMomentum / copy.momentOfInertia
        let angularSpeed = (angularVelocity * angularVelocity)
          .sum().squareRoot()
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
      result.frames.append(createFrame())
    }
    
    return result
  }
}
