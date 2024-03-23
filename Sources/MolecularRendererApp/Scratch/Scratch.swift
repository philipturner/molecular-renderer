// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Don't spend time testing reliability of long rods. Jump straight to
// the 4-bit CLA. Start by just laying out all of the logic rods, without knobs.
func createGeometry() -> [Entity] {
  return [Entity(position: .zero, type: .atom(.carbon))]
}
