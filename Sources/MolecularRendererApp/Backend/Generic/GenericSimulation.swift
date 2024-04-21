//
//  GenericSimulation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/20/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// A convenience method for de-duplicating the most common pieces of code.
struct GenericSimulation {
  var rigidBodies: [MM4RigidBody]
  var parameters: MM4Parameters
  var forceField: MM4ForceField
  
  init(rigidBodies: [MM4RigidBody]) {
    self.rigidBodies = rigidBodies
    self.parameters = Self.createParameters(rigidBodies: rigidBodies)
    self.forceField = Self.createForceField(parameters: parameters)
  }
  
  static func createParameters(rigidBodies: [MM4RigidBody]) -> MM4Parameters {
    var output = rigidBodies[0].parameters
    for rigidBodyID in 1..<rigidBodies.count {
      let rigidBody = rigidBodies[rigidBodyID]
      output.append(contentsOf: rigidBody.parameters)
    }
    return output
  }
  
  static func createForceField(parameters: MM4Parameters) -> MM4ForceField {
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.integrator = .multipleTimeStep
    forceFieldDesc.parameters = parameters
    return try! MM4ForceField(descriptor: forceFieldDesc)
  }
  
  mutating func withForceField(_ closure: (MM4ForceField) -> Void) {
    forceField.positions = rigidBodies.flatMap(\.positions)
    forceField.velocities = rigidBodies.flatMap(\.velocities)
    closure(forceField)
    
    var atomCursor: Int = .zero
    for rigidBodyID in rigidBodies.indices {
      var rigidBody = rigidBodies[rigidBodyID]
      let range = atomCursor..<atomCursor + rigidBody.parameters.atoms.count
      atomCursor += rigidBody.parameters.atoms.count
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = Array(forceField.positions[range])
      rigidBodyDesc.velocities = Array(forceField.velocities[range])
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      rigidBodies[rigidBodyID] = rigidBody
    }
  }
  
  // Create thermal velocities and set average momentum to zero.
  mutating func setVelocitiesToTemperature(_ temperature: Double) {
    // Create a temporary OpenMM system.
    let system = OpenMM_System()
    let positions = OpenMM_Vec3Array(size: 0)
    for rigidBody in rigidBodies {
      for atomID in rigidBody.parameters.atoms.indices {
        let massInYg = rigidBody.parameters.atoms.masses[atomID]
        let massInAmu = massInYg * Float(MM4AmuPerYg)
        system.addParticle(mass: Double(massInAmu))
        
        let positionInNm = rigidBody.positions[atomID]
        positions.append(SIMD3<Double>(positionInNm))
      }
    }
    
    // Fetch the reference platform.
    //
    // NOTE: Using the reference platform for temporary 'OpenMM_Context's
    // reduces the latency. It also avoids annoying OpenCL compiler warnings.
    let platforms = OpenMM_Platform.platforms
    let reference = platforms.first(where: { $0.name == "Reference" })
    guard let reference else {
      fatalError("Could not find reference platform.")
    }
    
    // Use the OpenMM host function for generating thermal velocities.
    let integrator = OpenMM_VerletIntegrator(stepSize: 0)
    let context = OpenMM_Context(
      system: system, integrator: integrator, platform: reference)
    context.positions = positions
    context.setVelocitiesToTemperature(temperature)
    
    // Cast the velocities from FP64 to FP32.
    let state = context.state(types: [.velocities])
    let velocitiesObject = state.velocities
    var velocities: [SIMD3<Float>] = []
    for atomID in 0..<velocitiesObject.size {
      let velocity64 = velocitiesObject[atomID]
      let velocity32 = SIMD3<Float>(velocity64)
      velocities.append(velocity32)
    }
    
    var atomCursor: Int = .zero
    for rigidBodyID in rigidBodies.indices {
      // Determine the atom range.
      var rigidBody = rigidBodies[rigidBodyID]
      let nextAtomCursor = atomCursor + rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      atomCursor += rigidBody.parameters.atoms.count
      
      // Create a new rigid body with the desired state.
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.positions = rigidBody.positions
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.velocities = Array(velocities[atomRange])
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      
      // Zero out the momentum.
      rigidBody.linearMomentum = .zero
      rigidBody.angularMomentum = .zero
      
      // Overwrite the current value in the array.
      rigidBodies[rigidBodyID] = rigidBody
    }
  }
}
