// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createNanoRobot() -> [[Entity]] {
  // TODO: Add some crystolecules from the built site to the center frame.
  // When the boolean for 'directionIn' is true, materialize them into the
  // simulator. Ensure the crystolecule stays between the grippers. Then, give
  // the build plate a velocity. Have it fly away for another ~70 frames.
  let robotFrame = RobotFrame()
  return robotFrame.animationFrames
}

extension RobotCenterPiece {
  mutating func compilationPass3() {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.bonds = topology.bonds
    paramsDesc.atomicNumbers = topology.atoms.map {
      if $0.atomicNumber == 1 { return 1 }
      else { return 6 }
    }
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    for i in topology.atoms.indices {
      if topology.atoms[i].atomicNumber == 14 {
        parameters.atoms.masses[i] = 0
      }
    }
    self.parameters = parameters
  }
}
