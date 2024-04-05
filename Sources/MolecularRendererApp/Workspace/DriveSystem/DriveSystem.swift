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
    // 5) Run MD simulation on 7900 XTX, serialize and debug in CAD program.
    // 6) Fix up the 'nano' lettering on the connecting rod.
    
    connectingRod = ConnectingRod()
    flywheel = Flywheel()
    housing = Housing()
    piston = Piston()
    
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    let flywheelOffset = SIMD3(10, 10, 10.3) * latticeConstant
    let pistonOffset = SIMD3(28.5, 10, 10.3) * latticeConstant
    let connectingRodOffset = SIMD3(-2.5, 10.3, 17.4) * latticeConstant
    
    flywheel.rigidBody.centerOfMass += flywheelOffset
    piston.rigidBody.centerOfMass += pistonOffset
    connectingRod.rigidBody.centerOfMass += connectingRodOffset
    
    // Correct for the shift that would occur after energy minimization.
    connectingRod.rigidBody.centerOfMass.x -= 0.22
    piston.rigidBody.centerOfMass.x -= 0.18
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
  // The parts must already be separated from each other. Example:
  // driveSystem.rotate(angle: .pi / 2, axis: [-1, 0, 0])
  // driveSystem.scale(factor: SIMD3(1.5, 4, 1.5))
  // driveSystem.shift(offset: SIMD3(0, -15, 0))
  mutating func minimize() {
    var forceFieldParameters = connectingRod.rigidBody.parameters
    forceFieldParameters.append(contentsOf: flywheel.rigidBody.parameters)
    do {
      var parameters = housing.rigidBody.parameters
      for atomID in parameters.atoms.indices {
        let centerType = parameters.atoms.centerTypes[atomID]
        if centerType == .quaternary {
//          parameters.atoms.masses[atomID] = .zero
        }
      }
      forceFieldParameters.append(contentsOf: parameters)
    }
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
}
