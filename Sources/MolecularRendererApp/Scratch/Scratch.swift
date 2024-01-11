// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createNanoRobot() -> [Entity] {
  let buildPlate = RobotBuildPlate(video: .version2)
  return buildPlate.topology.atoms
}
