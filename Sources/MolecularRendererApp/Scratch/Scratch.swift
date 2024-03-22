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
  let system = System()
  
  // Energy-minimize the surfaces, while allowing the bulk structures to warp.
  
  var atoms: [Entity] = []
  atoms += system.rod1.topology.atoms
  atoms += system.rod2.topology.atoms
  atoms += system.housing.topology.atoms
  return atoms
}
