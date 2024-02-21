// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Create a flywheel-driven drive system structure.
  return [Entity(position: .zero, type: .atom(.carbon))]
}
