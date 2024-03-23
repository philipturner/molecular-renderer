// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

import QuartzCore

// Test whether switches with sideways knobs work correctly. Test every
// possible permutation of touching knobs and approach directions.
//
// Then, test whether extremely long rods work correctly.
//
// Notes:
// - Save each test to 'rod-logic', in a distinct set of labeled files. Then,
//   overwrite the contents and proceed with the next test.
// - Run each setup with MD at room temperature.
func createGeometry() -> [[Entity]] {
  var system = System()
  system.alignParts()
  system.rigidBodies[1].centerOfMass += SIMD3(0, -2, 0)
  system.minimize()
  system.equilibriate(temperature: 298)

  do {
    // Select the last principal axis, and make it point toward +Z.
    var axis = system.rigidBodies[0].principalAxes.2
    if axis.z < 0 {
      axis = -axis
    }
    
    // Set the momentum of the rigid body.
    let m = system.rigidBodies[0].mass
    let v = -0.200 * axis
    system.rigidBodies[0].linearMomentum = m * v
  }
  
  var frames: [[Entity]] = []
  for frameID in 0...500 {
    if frameID > 0 {
      let checkpoint0 = CACurrentMediaTime()
      system.forceField.positions = system.rigidBodies.flatMap(\.positions)
      system.forceField.velocities = system.rigidBodies.flatMap(\.velocities)
      let checkpoint1 = CACurrentMediaTime()
      system.forceField.simulate(time: 0.100)
      let checkpoint2 = CACurrentMediaTime()
      system.updateRigidBodies()
      let checkpoint3 = CACurrentMediaTime()
      
      let checkpoints = [checkpoint0, checkpoint1, checkpoint2, checkpoint3]
      var elapsedTimes: [Double] = []
      for timeID in 1..<checkpoints.count {
        elapsedTimes.append(checkpoints[timeID] - checkpoints[timeID - 1])
      }
      
      print("frame:", frameID, terminator: " | ")
      for time in elapsedTimes {
        let us = Int(time * 1e6)
        print(us, terminator: " ")
      }
      print()
    } else {
      print("frame:", frameID)
    }
    
    let frame = system.createFrame()
    frames.append(frame)
  }
  return frames
}
