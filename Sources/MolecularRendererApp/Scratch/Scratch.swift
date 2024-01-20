// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

// Use the HDL to compile some structures for mechanosynthesis. Start by
// reproducing Robert's very first paper. Run through both xTB and Octopus,
// the compare the results to literature. Make a HardwareCatalog entry about
// this.
//
// Attempt to establish this workflow:
// - Preconditioning: GFN-FF
// - Minimization: GFN2-xTB
// - Final singlepoint analysis: Octopus

func createGeometry() -> [Entity] {
  let logicRod = LogicRod(length: 20)
  return logicRod.topology.atoms
}
