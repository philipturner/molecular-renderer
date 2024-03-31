//
//  TestRod.swift
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
struct TestRod {
  var rigidBody: MM4RigidBody
  
  init(rod: Rod) {
    // Create the MM4 parameters.
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = rod.topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = rod.topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    // Create the rigid body and center it.
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = rod.topology.atoms.map(\.position)
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    rigidBody.centerOfMass = .zero
    
    // Since the principal axes have a degenerate eigenspace, we must manually
    // rotate each class of logic rod.
    // rigidBody.rotate(angle: .pi / 2, axis: SIMD3(0, 1, 0)) // x-oriented
    // rigidBody.rotate(angle: .pi / 2, axis: SIMD3(-1, 0, 0)) // y-oriented
    // z-oriented does not require rotations
  }
}
#endif
