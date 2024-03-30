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
}
