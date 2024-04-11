//
//  DriveSystem.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/3/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

struct DriveSystem {
  var connectingRod: ConnectingRod
  var flywheel: Flywheel
  var housing: DriveSystemHousing
  var piston: Piston
  
  // Initialization sequence:
  // - call the system initializer
  // - minimize the connecting rod in isolation
  // - minimize the flywheel in isolation
  // - minimize the entire system
  init() {
    connectingRod = ConnectingRod()
    flywheel = Flywheel()
    housing = DriveSystemHousing()
    piston = Piston()
    
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    let flywheelOffset = SIMD3(10, 10, 10.3) * latticeConstant
    let pistonOffset = SIMD3(28.5, 10, 10.3) * latticeConstant
    let connectingRodOffset = SIMD3(-2.5, 10.3, 17.4) * latticeConstant
    
    flywheel.rigidBody.centerOfMass += flywheelOffset
    piston.rigidBody.centerOfMass += pistonOffset
    connectingRod.rigidBody.centerOfMass += connectingRodOffset
    
    connectingRod.rigidBody.centerOfMass.x -= 0.2
    piston.rigidBody.centerOfMass.x += 0.35
  }
  
  mutating func rotate(angle: Double, axis: SIMD3<Double>) {
    let quaternion = Quaternion(angle: angle, axis: axis)
    
    func rotate(rigidBody: inout MM4RigidBody) {
      var centerOfMass = rigidBody.centerOfMass
      rigidBody.centerOfMass -= centerOfMass
      rigidBody.rotate(angle: angle, axis: axis)
      centerOfMass = quaternion.act(on: centerOfMass)
      rigidBody.centerOfMass += centerOfMass
    }
    rotate(rigidBody: &connectingRod.rigidBody)
    rotate(rigidBody: &flywheel.rigidBody)
    rotate(rigidBody: &housing.rigidBody)
    rotate(rigidBody: &piston.rigidBody)
  }
  
  mutating func scale(factor: SIMD3<Double>) {
    connectingRod.rigidBody.centerOfMass *= factor
    flywheel.rigidBody.centerOfMass *= factor
    housing.rigidBody.centerOfMass *= factor
    piston.rigidBody.centerOfMass *= factor
  }
  
  mutating func shift(offset: SIMD3<Double>) {
    connectingRod.rigidBody.centerOfMass += offset
    flywheel.rigidBody.centerOfMass += offset
    housing.rigidBody.centerOfMass += offset
    piston.rigidBody.centerOfMass += offset
  }
}

extension DriveSystem {
  mutating func minimize() {
    var forceFieldParameters = connectingRod.rigidBody.parameters
    forceFieldParameters.append(contentsOf: flywheel.rigidBody.parameters)
    forceFieldParameters.append(contentsOf: housing.rigidBody.parameters)
    forceFieldParameters.append(contentsOf: piston.rigidBody.parameters)
    
    var forceFieldPositions = connectingRod.rigidBody.positions
    forceFieldPositions += flywheel.rigidBody.positions
    forceFieldPositions += housing.rigidBody.positions
    forceFieldPositions += piston.rigidBody.positions
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = forceFieldParameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = forceFieldPositions
    forceField.minimize(tolerance: 10)
    
    var atomCursor: Int = .zero
    func update(rigidBody: inout MM4RigidBody) {
      let nextAtomCursor = atomCursor + rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      atomCursor = nextAtomCursor
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = Array(forceField.positions[atomRange])
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    update(rigidBody: &connectingRod.rigidBody)
    update(rigidBody: &flywheel.rigidBody)
    update(rigidBody: &housing.rigidBody)
    update(rigidBody: &piston.rigidBody)
  }
  
  // Create thermal velocities and set average momentum to zero.
  //
  // WARNING: This will erase any previous value for the momentum.
  mutating func setVelocitiesToTemperature(_ temperature: Double) {
    var rigidBodies = [
      connectingRod.rigidBody,
      flywheel.rigidBody,
      housing.rigidBody,
      piston.rigidBody,
    ]
    
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
    
    connectingRod.rigidBody = rigidBodies[0]
    flywheel.rigidBody = rigidBodies[1]
    housing.rigidBody = rigidBodies[2]
    piston.rigidBody = rigidBodies[3]
  }
}
