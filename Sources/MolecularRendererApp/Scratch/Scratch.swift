// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let logicRod = LogicRod(length: 20)
  return logicRod.topology.atoms
}
