// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// WARNING: The renderer is currently in 'MRSceneSize.extreme'. It will not
// render any animations.
func createGeometry() -> [Entity] {
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
  
  // TODO: Next, remove the collisions between the carry-chain rods and the
  // A/B operand rods. Keep the clock signal direction in mind.
  //
  // In addition, pattern the 'generate' rods to respond to the A/B operands.
  
  // Create the atoms.
  var atoms: [Entity] = []
  for rod in circuit.input.rods {
    atoms += rod.topology.atoms
  }
  for rod in circuit.propagate.signal {
    atoms += rod.topology.atoms
  }
  for rod in circuit.generate.signal {
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
}
