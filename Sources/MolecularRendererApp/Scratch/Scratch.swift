// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Solve the Kohn-Sham equation with finite-differencing, visualizing the
  // evolution of the 2s orbital into the 1s orbital. Then, experiment with
  // variable-resolution orbitals and multigrids.
  return [Entity(position: .zero, type: .atom(.carbon))]
}
