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

struct DriveSystem {
  var rigidBodies: [MM4RigidBody] = []
  
  init() {
    // 1) Each part materializes in the state immediately after compilation.
    // 2) Energy-minimize while in the air, a few steps at a time.
    // 3) Compress down into assembled structure, rotate toward viewer.
    // 4) Run RBD simulation.
    // 5) Run MD simulation on 7900 XTX, serialize.
    // 6) Serialized simulation -> GIF pipeline.
    
    var housing = Housing()
    
    var flywheel = Flywheel()
    let latticeConstant = Constant(.square) { .elemental(.carbon) }
    flywheel.rigidBody.centerOfMass.x += Double(10 * latticeConstant)
    flywheel.rigidBody.centerOfMass.y += Double(10 * latticeConstant)
    flywheel.rigidBody.centerOfMass.z += Double(10.3 * latticeConstant)
    
    var piston = Piston()
    piston.rigidBody.centerOfMass.x += Double(28.5 * latticeConstant)
    piston.rigidBody.centerOfMass.y += Double(10 * latticeConstant)
    piston.rigidBody.centerOfMass.z += Double(10.3 * latticeConstant)
    
    var connectingRod = ConnectingRod()
    connectingRod.rigidBody.centerOfMass.x += Double(-2.5 * latticeConstant)
    connectingRod.rigidBody.centerOfMass.y += Double(10.3 * latticeConstant)
    connectingRod.rigidBody.centerOfMass.z += Double(17.4 * latticeConstant)
    
    func minimize(rigidBody: inout MM4RigidBody) {
      var forceFieldDesc = MM4ForceFieldDescriptor()
      forceFieldDesc.parameters = rigidBody.parameters
      let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
      forceField.positions = rigidBody.positions
      forceField.minimize(tolerance: 0.1)
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = forceField.positions
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    
    #if true
    minimize(rigidBody: &flywheel.rigidBody)
    minimize(rigidBody: &piston.rigidBody)
    minimize(rigidBody: &connectingRod.rigidBody)
    
    // Energy-minimize the housing's surface atoms (hasty solution).
    do {
      var parameters = housing.rigidBody.parameters
      for atomID in parameters.atoms.indices {
        let centerType = parameters.atoms.centerTypes[atomID]
        if centerType == .quaternary {
          parameters.atoms.masses[atomID] = .zero
        }
      }
      
      var forceFieldDesc = MM4ForceFieldDescriptor()
      forceFieldDesc.parameters = parameters
      let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
      forceField.positions = housing.rigidBody.positions
      forceField.minimize()
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = housing.rigidBody.parameters
      rigidBodyDesc.positions = forceField.positions
      housing.rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    #endif
    
    rigidBodies.append(housing.rigidBody)
    rigidBodies.append(flywheel.rigidBody)
    rigidBodies.append(piston.rigidBody)
    rigidBodies.append(connectingRod.rigidBody)
  }
}
