import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // First task: fix up the "nano" patterning
  // Second task: set up the exploded view, and the more efficient minimization
  //
  // Not yet the right time to publish an animation. Better use of time would
  // be making more progress on rod logic.
  
  let driveSystem = DriveSystem()
  var output: [MM4RigidBody] = []
  output.append(driveSystem.connectingRod.rigidBody)
  output.append(driveSystem.flywheel.rigidBody)
  output.append(driveSystem.housing.rigidBody)
  output.append(driveSystem.piston.rigidBody)
  return []
}
