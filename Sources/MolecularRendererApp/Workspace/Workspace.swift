import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Finish the flywheel before doing bootstrapping animation.
//
// Tasks:
// - Get the flywheel working with MD, publish short animation
// - Don't have to get working method to link up to logic; just explain how
//   that would work
// - Don't have to finish patterning all the logic rods in the CLA; the
//   existing progress is enough
//
// Flywheel System Animation:
// - atoms materialize in Morton order, in exploded view
// - energy-minimize from compiled to relaxed structure
//   - show each frame of the minimization, if practical
// - assemble parts on top of each other
// - rotate so the flywheel points toward viewer
// - molecular dynamics simulation (base64-encoded [Entity])

func createGeometry() -> [MM4RigidBody] {
  // First task: fix up the "nano" patterning
  // Second task: set up the exploded view, and the more efficient minimization
  //
  // It should be possible to finish both of these parts tonight, and get some
  // initial testing of the MD sim. Tomorrow should be full simulation on AMD
  // and recording/publishing the animation.
  
  let driveSystem = DriveSystem()
  var output: [MM4RigidBody] = []
  output.append(driveSystem.connectingRod.rigidBody)
  output.append(driveSystem.flywheel.rigidBody)
  output.append(driveSystem.housing.rigidBody)
  output.append(driveSystem.piston.rigidBody)
  return []
}
