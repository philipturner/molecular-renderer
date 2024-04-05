import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // First task: set up the exploded view, and the more efficient minimization
  //
  // Not yet the right time to publish an animation. Better use of time would
  // be making more progress on rod logic.
  
  // TODO: Energy-minimize the connecting rod first, then the rest of the system.
  // .minimizeConnectingRod()
  // .minimizeSystem()
  
  var driveSystem = DriveSystem()
//  driveSystem.rotate(angle: .pi / 2, axis: [-1, 0, 0])
//  driveSystem.scale(factor: SIMD3(1.5, 4, 1.5))
//  driveSystem.shift(offset: SIMD3(0, -15, 0))
  driveSystem.minimize()
  
  var output: [MM4RigidBody] = []
//  output.append(driveSystem.connectingRod.rigidBody)
  output.append(driveSystem.flywheel.rigidBody)
  output.append(driveSystem.housing.rigidBody)
  output.append(driveSystem.piston.rigidBody)
  return output
}
