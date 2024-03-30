// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

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
  let axes = rigidBody.principalAxes
  for atomID in rod.topology.atoms.indices {
    var atom = rod.topology.atoms[atomID]
    let position = rigidBody.positions[atomID]
    atom.position = position
    rod.topology.atoms[atomID] = atom
  }
  
  return rod.topology.atoms
}
