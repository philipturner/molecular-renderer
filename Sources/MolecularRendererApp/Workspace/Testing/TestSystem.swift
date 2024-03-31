//
//  Scratch3.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/30/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

#if false
struct TestSystem {
  // The objects for the compiled parts.
  var testHousing: TestHousing
  var testRod: TestRod
  
  // The forcefield object that gets recycled for multiple simulation runs.
  var forceFieldParameters: MM4Parameters!
  var forceField: MM4ForceField!
  
  init(testHousing: TestHousing, testRod: TestRod) {
    self.testHousing = testHousing
    self.testRod = testRod
    
    createForceField()
  }
  
  mutating func createForceField() {
    // Create a collective parameters object to describe the entire scene.
    var emptyParamsDesc = MM4ParametersDescriptor()
    emptyParamsDesc.atomicNumbers = []
    emptyParamsDesc.bonds = []
    forceFieldParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
    for rigidBody in [testHousing.rigidBody!, testRod.rigidBody] {
      let partParameters = rigidBody.parameters
      forceFieldParameters.append(contentsOf: partParameters)
    }
    
    // Set up the force field.
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.cutoffDistance = 2
    forceFieldDesc.integrator = .multipleTimeStep
    forceFieldDesc.parameters = forceFieldParameters
    forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  }
  
  // Overwrite the rigid bodies with the force field's current state.
  //
  // NOTE: You can treat the force field state as transient.
  mutating func updateRigidBodies() {
    var atomCursor: Int = .zero
    do {
      // Determine the atom range.
      var nextAtomCursor = atomCursor
      nextAtomCursor += testHousing.rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      
      // Create a new rigid body with the desired state.
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.positions = Array(forceField.positions[atomRange])
      rigidBodyDesc.parameters = testHousing.rigidBody.parameters
      rigidBodyDesc.velocities = Array(forceField.velocities[atomRange])
      testHousing.rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    
    atomCursor += testHousing.rigidBody.parameters.atoms.count
    do {
      // Determine the atom range.
      var nextAtomCursor = atomCursor
      nextAtomCursor += testRod.rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      
      // Create a new rigid body with the desired state.
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.positions = Array(forceField.positions[atomRange])
      rigidBodyDesc.parameters = testRod.rigidBody.parameters
      rigidBodyDesc.velocities = Array(forceField.velocities[atomRange])
      testRod.rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
  }
  
  // Create a frame for animation.
  func createFrame() -> [Entity] {
    func createAtoms(rigidBody: MM4RigidBody) -> [Entity] {
      var output: [Entity] = []
      for atomID in rigidBody.parameters.atoms.indices {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let storage = SIMD4(position, Float(atomicNumber))
        output.append(Entity(storage: storage))
      }
      return output
    }
    
    var output: [Entity] = []
    output += createAtoms(rigidBody: testHousing.rigidBody)
    output += createAtoms(rigidBody: testRod.rigidBody)
    return output
  }
}

// MARK: - Simulation

extension TestSystem {
  // Minimize the potential energy at zero temperature.
  mutating func minimize() {
    // Assign the rigid body states to the forcefield.
    var positions: [SIMD3<Float>] = []
    positions += testHousing.rigidBody.positions
    positions += testRod.rigidBody.positions
    forceField.positions = positions
    
    // Conduct the energy minimization.
    forceField.minimize()
    
    // Assign the forcefield state to the rigid bodies.
    updateRigidBodies()
  }
  
  // Equilibriate the thermal potential energy, and save the associated
  // thermal kinetic state.
  mutating func equilibriate(temperature: Double) {
    let equilibriationTime: Double = 1
    
    // Iterate once at twice the energy, then 5 times at the correct energy.
    for iterationID in 0...5 {
      var effectiveTemperature: Double
      if iterationID == 0 {
        effectiveTemperature = temperature * 2
      } else {
        effectiveTemperature = temperature
      }
      setVelocitiesToTemperature(effectiveTemperature)
      
      // Zero out the bulk momenta.
      updateRigidBodies()
      testHousing.rigidBody.linearMomentum = .zero
      testHousing.rigidBody.angularMomentum = .zero
      testRod.rigidBody.linearMomentum = .zero
      testRod.rigidBody.angularMomentum = .zero
      
      // Update the force field's positions.
      var positions: [SIMD3<Float>] = []
      positions += testHousing.rigidBody.positions
      positions += testRod.rigidBody.positions
      forceField.positions = positions
      
      // Update the force field's velocities.
      var velocities: [SIMD3<Float>] = []
      velocities += testHousing.rigidBody.velocities
      velocities += testRod.rigidBody.velocities
      forceField.velocities = velocities
      
      // Divide the equilibriation time among the iterations.
      if iterationID == 0 {
        forceField.simulate(time: equilibriationTime / 2)
      } else {
        forceField.simulate(time: equilibriationTime / 10)
      }
    }
    
    // Update the rigid bodies with the final thermal kinetic state.
    updateRigidBodies()
    testHousing.rigidBody.linearMomentum = .zero
    testHousing.rigidBody.angularMomentum = .zero
    testRod.rigidBody.linearMomentum = .zero
    testRod.rigidBody.angularMomentum = .zero
  }
  
  // Create the thermal kinetic state from the Boltzmann distribution.
  //
  // The absence of 'mutating' expresses that this function doesn't
  // update the rigid bodies.
  func setVelocitiesToTemperature(_ temperature: Double) {
    // Create a temporary OpenMM system.
    let system = OpenMM_System()
    let positions = OpenMM_Vec3Array(size: 0)
    for rigidBody in [testHousing.rigidBody!, testRod.rigidBody] {
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
    
    // Assign the force field state.
    forceField.velocities = velocities
  }
}
#endif

struct TestSystem {
  // The objects for the compiled parts.
  var testDriveWall: TestDriveWall
  var testRod: TestRod
  
  // The forcefield object that gets recycled for multiple simulation runs.
  var forceFieldParameters: MM4Parameters!
  var forceField: MM4ForceField!
  
  init(testDriveWall: TestDriveWall, testRod: TestRod) {
    self.testDriveWall = testDriveWall
    self.testRod = testRod
  }
  
  mutating func createForceField() {
    // Create a collective parameters object to describe the entire scene.
    var emptyParamsDesc = MM4ParametersDescriptor()
    emptyParamsDesc.atomicNumbers = []
    emptyParamsDesc.bonds = []
    forceFieldParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
    for rigidBody in [testDriveWall.rigidBody!, testRod.rigidBody!] {
      let partParameters = rigidBody.parameters
      forceFieldParameters.append(contentsOf: partParameters)
    }
    
    // Set up the force field.
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.cutoffDistance = 2
    forceFieldDesc.integrator = .multipleTimeStep
    forceFieldDesc.parameters = forceFieldParameters
    forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  }
  
  // Overwrite the rigid bodies with the force field's current state.
  //
  // NOTE: You can treat the force field state as transient.
  mutating func updateRigidBodies() {
    var atomCursor: Int = .zero
    do {
      // Determine the atom range.
      var nextAtomCursor = atomCursor
      nextAtomCursor += testDriveWall.rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      
      // Create a new rigid body with the desired state.
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.positions = Array(forceField.positions[atomRange])
      rigidBodyDesc.parameters = testDriveWall.rigidBody.parameters
      rigidBodyDesc.velocities = Array(forceField.velocities[atomRange])
      testDriveWall.rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    
    atomCursor += testDriveWall.rigidBody.parameters.atoms.count
    do {
      // Determine the atom range.
      var nextAtomCursor = atomCursor
      nextAtomCursor += testRod.rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      
      // Create a new rigid body with the desired state.
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.positions = Array(forceField.positions[atomRange])
      rigidBodyDesc.parameters = testRod.rigidBody.parameters
      rigidBodyDesc.velocities = Array(forceField.velocities[atomRange])
      testRod.rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
  }
  
  // Create a frame for animation.
  func createFrame() -> [Entity] {
    func createAtoms(rigidBody: MM4RigidBody) -> [Entity] {
      var output: [Entity] = []
      for atomID in rigidBody.parameters.atoms.indices {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let storage = SIMD4(position, Float(atomicNumber))
        output.append(Entity(storage: storage))
      }
      return output
    }
    
    var output: [Entity] = []
    output += createAtoms(rigidBody: testDriveWall.rigidBody)
    output += createAtoms(rigidBody: testRod.rigidBody)
    return output
  }
}

// MARK: - Simulation

extension TestSystem {
  // Minimize the potential energy at zero temperature.
  mutating func minimize(tolerance: Double) {
    // Assign the rigid body states to the forcefield.
    var positions: [SIMD3<Float>] = []
    positions += testDriveWall.rigidBody.positions
    positions += testRod.rigidBody.positions
    forceField.positions = positions
    
    // Conduct the energy minimization.
    forceField.minimize(tolerance: tolerance)
    
    // Assign the forcefield state to the rigid bodies.
    updateRigidBodies()
  }
}
