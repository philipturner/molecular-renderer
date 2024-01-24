// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  var descriptor = LogicRodDescriptor()
  descriptor.length = 30
  descriptor.indentations = [
    4..<6, 12..<16, 20..<24, 28..<32
  ]
  let rod = LogicRod(descriptor: descriptor)
  return rod.topology.atoms
}
