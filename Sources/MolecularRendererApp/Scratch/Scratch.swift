// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createNanoRobot() -> [[Entity]] {
  let robotFrame = RobotFrame()
  
  var output: [[Entity]] = []
  output += robotFrame.animationFrames
  return output
}
