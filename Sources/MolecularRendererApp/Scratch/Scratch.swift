// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let scene = TooltipScene()
  return scene.tooltips[3 * 3].topology.atoms
}
