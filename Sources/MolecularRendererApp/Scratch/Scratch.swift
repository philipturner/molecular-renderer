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
  
  var rod = circuit.propagate.broadcast.values.first!
//  return [rod.topology.atoms]
  
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
  for frameID in 0...240 {
    if frameID > 0 {
      forceField.simulate(time: 0.040)
      print(forceField.energy.potential, forceField.energy.kinetic)
    }
    print("frame:", frameID)
    
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
  
  #if false
  // Create the atoms.
  var atoms: [Entity] = []
  for rod in circuit.input.rods {
    atoms += rod.topology.atoms
  }
  for rod in circuit.propagate.broadcast.values {
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
  return atoms
#endif
}
