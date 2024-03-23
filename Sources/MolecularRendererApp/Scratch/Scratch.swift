// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Test whether switches with sideways knobs work correctly. Test every
// possible permutation of touching knobs and approach directions.
//
// Then, test whether extremely long rods work correctly.
//
// Notes:
// - Save each test to 'rod-logic', in a distinct set of labeled files. Then,
//   overwrite the contents and proceed with the next test.
// - Run each setup with MD at room temperature.
func createGeometry() -> [Entity] {
  var system = System()
  system.minimize()
  system.equilibriate(temperature: 298)
  
  // Conserve the thermal kinetic state associated with the thermal potential
  // state above. Set each rigid body's bulk momentum to the desired value. Use
  // the current inertial eigenbasis, as it shifts with thermal potential state.
  
  var atoms: [Entity] = []
  atoms += system.rod1.topology.atoms
  atoms += system.rod2.topology.atoms
  atoms += system.housing.topology.atoms
  for i in atoms.indices {
    atoms[i].position = system.forceField!.positions[i]
  }
  return atoms
}
