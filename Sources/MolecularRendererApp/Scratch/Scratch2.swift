//
//  Scratch2.swift
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

// WARNING: The renderer could be in 'MRSceneSize.extreme'. If so, it will not
// render any animations.
func createGeometry() -> [[Entity]] {
  // Create the scene.
  let circuit = Circuit()
  
  // TODO: Check whether logic rods with P dopants still interact with housing
  // in the same way as non-doped rods.
  
  #if true
  // Create the atoms.
  var atoms: [Entity] = []
  for rod in circuit.generate.rods {
    atoms += rod.topology.atoms
  }
  
  // Center the scene at the origin.
  var centerOfMass: SIMD3<Float> = .zero
  for atomID in atoms.indices {
    centerOfMass += atoms[atomID].position
  }
  centerOfMass /= Float(atoms.count)
  for atomID in atoms.indices {
    atoms[atomID].position -= centerOfMass
  }
  
  // Return the atoms.
  return [atoms]
  #else
  
  let rod = circuit.propagate.probe[2]!
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = rod.topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = rod.topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = rod.topology.atoms.map(\.position)
  forceField.minimize()
  
  
  
  var frames: [[Entity]] = []
  for frameID in 0...500 {
    if frameID > 0 {
      forceField.simulate(time: 0.100)
    }
    print("frame:", frameID)
    
    #if false
    do {
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = parameters
      rigidBodyDesc.positions = forceField.positions
      rigidBodyDesc.velocities = forceField.velocities
      var rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      rigidBody.angularMomentum = .zero
      rigidBody.linearMomentum = .zero
      rigidBody.centerOfMass = .zero
      
      let axesFP64 = rigidBody.principalAxes
      let axes = (
        SIMD3<Float>(axesFP64.0),
        SIMD3<Float>(axesFP64.1),
        SIMD3<Float>(axesFP64.2))
      func transform(direction: SIMD3<Float>) -> SIMD3<Float> {
        let dotProduct1 = (direction * axes.0).sum()
        let dotProduct2 = (direction * axes.1).sum()
        let dotProduct3 = (direction * axes.2).sum()
        return SIMD3(dotProduct1, dotProduct2, dotProduct3)
      }
      forceField.velocities = rigidBody.velocities.map(transform(direction:))
      forceField.positions = rigidBody.positions.map(transform(direction:))
    }
    #endif
    
    var frame: [Entity] = []
    for atomID in rod.topology.atoms.indices {
      var atom = rod.topology.atoms[atomID]
      let position = forceField.positions[atomID]
      atom.position = position
      frame.append(atom)
    }
    frames.append(frame)
  }
  return frames
  #endif
}

#endif

#if false
// WARNING: The renderer could be in 'MRSceneSize.extreme'. If so, it will not
// render any animations.
func createGeometry() -> [Entity] {
  // Create the scene.
  let circuit = Circuit()
  
  // TODO: Check whether logic rods with P dopants still interact with housing
  // in the same way as non-doped rods.
  //
  // Reproduce the algorithm for equilibriating thermal energy, and simulate
  // ambient/passive dynamics 300 K.
  
  var rod = circuit.propagate.broadcast[SIMD2(0, 1)]!
  
  // Create the MM4 parameters.
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = rod.topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = rod.topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  // Create the rigid body and center it.
  var rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.parameters = parameters
  rigidBodyDesc.positions = rod.topology.atoms.map(\.position)
  var rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  rigidBody.centerOfMass = .zero
  
  // Since the principal axes have a degenerate eigenspace, we must manually
  // rotate each class of logic rod.
  // rigidBody.rotate(angle: .pi / 2, axis: SIMD3(0, 1, 0)) // x-oriented
  // rigidBody.rotate(angle: .pi / 2, axis: SIMD3(-1, 0, 0)) // y-oriented
  // z-oriented does not require rotations
  
  // Copy the positions into the 'Topology'.
  for atomID in rod.topology.atoms.indices {
    var atom = rod.topology.atoms[atomID]
    let position = rigidBody.positions[atomID]
    atom.position = position
    rod.topology.atoms[atomID] = atom
  }
  
  return rod.topology.atoms
}
#endif
