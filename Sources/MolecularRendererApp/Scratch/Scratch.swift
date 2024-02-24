// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Smaller test system: full adder driven by the signal source. Should have
  // an interface for inputs and an interface for outputs.
  return [Entity(position: .zero, type: .atom(.carbon))]
}
