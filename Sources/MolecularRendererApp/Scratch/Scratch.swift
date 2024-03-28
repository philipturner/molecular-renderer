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
  
  // Tasks:
  // - Finish patterning the generate unit.
  // - Revise the propagate unit to follow the "clockingShift" convention from
  //   the generate unit.
  // - Revise the signal rods of the propagate unit to use a "clockingShift"
  //   convention, letting you model what happens after they're mobile (sort
  //   of a substitute for animation).
  
  // Create the atoms.
  var atoms: [Entity] = []
  for rod in circuit.propagate.signal {
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
