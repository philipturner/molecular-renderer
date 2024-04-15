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
  
  var rigidBodies: [MM4RigidBody] {
    var output: [MM4RigidBody] = []
    output.append(connectingRod.rigidBody)
    output.append(flywheel.rigidBody)
    output.append(housing.rigidBody)
    output.append(piston.rigidBody)
    return output
  }
  
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
    
    let housingCenter = housing.rigidBody.centerOfMass
    connectingRod.rigidBody.centerOfMass -= housingCenter
    flywheel.rigidBody.centerOfMass -= housingCenter
    housing.rigidBody.centerOfMass -= housingCenter
    piston.rigidBody.centerOfMass -= housingCenter
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
  
  // Initialize the flywheel's angular velocity and correct for the shift in
  // net momentum.
  //
  // WARNING: Ensure the drive system's rigid bodies are overwritten with the
  // current state, not just some copies in the calling program.
  mutating func initializeFlywheel(frequencyInGHz: Double) {
    func destroyOrganizedKineticEnergy(rigidBody: inout MM4RigidBody) {
      rigidBody.angularMomentum = .zero
      rigidBody.linearMomentum = .zero
    }
    func destroyThermalKineticEnergy(rigidBody: inout MM4RigidBody) {
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = rigidBody.positions
      
      let atomCount = rigidBody.parameters.atoms.count
      let velocities = [SIMD3<Float>](repeating: .zero, count: atomCount)
      rigidBodyDesc.velocities = velocities
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    func transferThermalKineticEnergy(
      from source: MM4RigidBody,
      to destination: inout MM4RigidBody
    ) {

      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = destination.parameters
      rigidBodyDesc.positions = destination.positions
      
      let atomCount = destination.parameters.atoms.count
      var velocities = [SIMD3<Float>](repeating: .zero, count: atomCount)
      for atomID in 0..<atomCount {
        velocities[atomID] += source.velocities[atomID]
        velocities[atomID] += destination.velocities[atomID]
      }
      rigidBodyDesc.velocities = velocities
      destination = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    
    // Zero out the net momentum in every rigid body.
    destroyOrganizedKineticEnergy(rigidBody: &connectingRod.rigidBody)
    destroyOrganizedKineticEnergy(rigidBody: &flywheel.rigidBody)
    destroyOrganizedKineticEnergy(rigidBody: &housing.rigidBody)
    destroyOrganizedKineticEnergy(rigidBody: &piston.rigidBody)
    
    // Save a copy that contains the thermal velocities.
    let copy = self
    
    // Destroy the thermal energy.
    destroyThermalKineticEnergy(rigidBody: &connectingRod.rigidBody)
    destroyThermalKineticEnergy(rigidBody: &flywheel.rigidBody)
    destroyThermalKineticEnergy(rigidBody: &housing.rigidBody)
    destroyThermalKineticEnergy(rigidBody: &piston.rigidBody)
    
    // Choose the axis that the flywheel will rotate around.
    let rotationAxis = flywheel.rigidBody.principalAxes.0
    guard rotationAxis.z > 0.999 else {
      fatalError("Flywheel was not aligned to expected reference frame.")
    }
    
    // Find the values of 'r' and 'l'.
    let flywheelPosition = DriveSystemPartPosition(source: flywheel)
    let pistonPosition = DriveSystemPartPosition(source: piston)
    var rDelta = flywheelPosition.knobCenter - flywheelPosition.bodyCenter
    var lDelta = flywheelPosition.knobCenter - pistonPosition.knobCenter
    rDelta -= (rDelta * rotationAxis).sum() * rotationAxis
    lDelta -= (lDelta * rotationAxis).sum() * rotationAxis
    let r = (rDelta * rDelta).sum().squareRoot()
    let l = (lDelta * lDelta).sum().squareRoot()
    print("value of r:", r)
    print("value of l:", l)
    
    // Set the flywheel's angular speed.
    let ω_f = frequencyInGHz * 0.001 * (2 * .pi)
    do {
      let I = flywheel.rigidBody.momentOfInertia
      let L_f = I * SIMD3(-ω_f, 0, 0)
      flywheel.rigidBody.angularMomentum += L_f
    }
    
    // Set the connecting rod's initial velocity.
    do {
      var rigidBody = connectingRod.rigidBody
      let (axis0, axis1, axis2) = connectingRod.rigidBody.principalAxes
      let principalAxes = [axis0, axis1, axis2]
      
      let v_c = (1.0 / 2) * (r * ω_f)
      let p_c = rigidBody.mass * SIMD3<Double>(0, v_c, 0)
      rigidBody.linearMomentum += p_c
      
      var ω_c: SIMD3<Double> = .zero
      for axisID in 0..<3 {
        let axis = principalAxes[axisID]
        let component = (axis * rotationAxis).sum() * (-r / l) * ω_f
        ω_c[axisID] = component
      }
      let L_c = rigidBody.momentOfInertia * ω_c
      rigidBody.angularMomentum += L_c
      
      connectingRod.rigidBody = rigidBody
    }
    
    // Restore the system's net momentum to zero.
    do {
      var forceFieldParameters = rigidBodies[0].parameters
      var forceFieldPositions = rigidBodies[0].positions
      var forceFieldVelocities = rigidBodies[0].velocities
      for rigidBody in rigidBodies[1...] {
        forceFieldParameters.append(contentsOf: rigidBody.parameters)
        forceFieldPositions.append(contentsOf: rigidBody.positions)
        forceFieldVelocities.append(contentsOf: rigidBody.velocities)
      }
      
      // Create a system rigid body for zeroing out linear momentum.
      var systemRigidBodyDesc = MM4RigidBodyDescriptor()
      systemRigidBodyDesc.parameters = forceFieldParameters
      systemRigidBodyDesc.positions = forceFieldPositions
      systemRigidBodyDesc.velocities = forceFieldVelocities
      var systemRigidBody = try! MM4RigidBody(descriptor: systemRigidBodyDesc)
      systemRigidBody.linearMomentum = .zero
      
      var atomCursor: Int = .zero
      func save(rigidBody: inout MM4RigidBody) {
        let atomCount = rigidBody.parameters.atoms.count
        let range = atomCursor..<atomCursor + atomCount
        
        var rigidBodyDesc = MM4RigidBodyDescriptor()
        rigidBodyDesc.parameters = rigidBody.parameters
        rigidBodyDesc.positions = Array(systemRigidBody.positions[range])
        rigidBodyDesc.velocities = Array(systemRigidBody.velocities[range])
        rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
        
        atomCursor += atomCount
      }
      save(rigidBody: &connectingRod.rigidBody)
      save(rigidBody: &flywheel.rigidBody)
      save(rigidBody: &housing.rigidBody)
      save(rigidBody: &piston.rigidBody)
    }
    
    // Add the thermal energy back in.
    transferThermalKineticEnergy(
      from: copy.connectingRod.rigidBody, to: &connectingRod.rigidBody)
    transferThermalKineticEnergy(
      from: copy.flywheel.rigidBody, to: &flywheel.rigidBody)
    transferThermalKineticEnergy(
      from: copy.housing.rigidBody, to: &housing.rigidBody)
    transferThermalKineticEnergy(
      from: copy.piston.rigidBody, to: &piston.rigidBody)
  }
}
