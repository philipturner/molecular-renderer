// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Sketch all of the moving parts for a flywheel drive system, without the
  // housing. It's okay if each part is a solid, unmanufacturable piece.
  return [Entity(position: .zero, type: .atom(.carbon))]
}
