// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// WARNING: The renderer is currently in 'MRSceneSize.extreme'. It will not
// render any animations.
func createGeometry() -> [[Entity]] {
  // Create the scene.
  let circuit = Circuit()
  
  // Currently adding the pattern to the rods.
  //
  // Next:
  //
  // Animate the circuit that check that there's no collisions with knobs.
  // Then, add the drive walls and simulate with RBD. Positionally
  // constrain the logic rods during the RBD simulation, saving compute cost
  // and deferring the compilation of housing until later.
  
  // TODO: Re-evaluate the propagate broadcast rods, with the new phosphorus
  // doping scheme instead of silicon doping. Of and only if this works,
  // proceed with replacing all silicon dopants with phosphorus.
  
  #if false
  // Create the atoms.
  var atoms: [Entity] = []
  let rod = circuit.propagate.broadcast[SIMD2(2, 4)]!
  atoms += rod.topology.atoms
  
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
  
  let rod = circuit.propagate.broadcast[SIMD2(2, 4)]!
  
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
