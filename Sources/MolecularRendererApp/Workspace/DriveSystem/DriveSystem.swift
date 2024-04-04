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
  var connectingRod: ConnectingRod
  var flywheel: Flywheel
  var housing: Housing
  var piston: Piston
  
  init() {
    // 1) Each part materializes in the state immediately after compilation.
    // 2) Energy-minimize while in the air, a few steps at a time.
    // 3) Compress down into assembled structure, rotate toward viewer.
    // 4) Run RBD simulation.
    // 5) Run MD simulation on 7900 XTX, serialize.
    // 6) Serialized simulation -> GIF pipeline.
    
    housing = Housing()
    flywheel = Flywheel()
    piston = Piston()
    connectingRod = ConnectingRod()
    
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    let flywheelOffset = SIMD3(10, 10, 10.3) * latticeConstant
    let pistonOffset = SIMD3(28.5, 10, 10.3) * latticeConstant
    let connectingRodOffset = SIMD3(-2.5, 10.3, 17.4) * latticeConstant
    
    flywheel.rigidBody.centerOfMass += flywheelOffset
    piston.rigidBody.centerOfMass += pistonOffset
    connectingRod.rigidBody.centerOfMass += connectingRodOffset
    
    func minimize(rigidBody: inout MM4RigidBody, surfaceOnly: Bool) {
      var parameters = rigidBody.parameters
      if surfaceOnly {
        for atomID in parameters.atoms.indices {
          let centerType = parameters.atoms.centerTypes[atomID]
          if centerType == .quaternary {
            parameters.atoms.masses[atomID] = .zero
          }
        }
      }
      
      var forceFieldDesc = MM4ForceFieldDescriptor()
      forceFieldDesc.parameters = parameters
      let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
      forceField.positions = rigidBody.positions
      forceField.minimize(tolerance: 0.1)
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = forceField.positions
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    
    #if false
    minimize(rigidBody: &flywheel.rigidBody, surfaceOnly: false)
    minimize(rigidBody: &piston.rigidBody, surfaceOnly: false)
    minimize(rigidBody: &connectingRod.rigidBody, surfaceOnly: false)
    minimize(rigidBody: &housing.rigidBody, surfaceOnly: true)
    #endif
  }
}
