// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import PythonKit

func createGeometry() -> [Entity] {
  PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
  testGOSPEL()

  let scene = TooltipScene()
  return scene.tooltips[3 * 3].topology.atoms
}

func testGOSPEL() {
  // Run 'lobpcg_test1' next.
}
