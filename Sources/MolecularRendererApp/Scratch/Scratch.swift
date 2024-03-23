// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

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
  system.rigidBodies[0].centerOfMass += SIMD3(0, 0, -2.00)
  system.minimize()
  system.equilibriate(temperature: 298)
  
  do {
    // Select the last principal axis, and make it point toward +Y.
    var axis = system.rigidBodies[1].principalAxes.2
    if axis.y < 0 {
      axis = -axis
    }
    
    // NOTES:
    //
    // Sideways-Sideways Knobs: fails when rod1 = 700 m/s
    // Sideways-Vertical Knobs: fails when rod1 = 700 m/s
    // Sideways-Vertical Knobs: fails when rod2 = 800 m/s
    
    // Set the momentum of the rigid body.
    let m = system.rigidBodies[1].mass
    let v = -0.800 * axis
    
    system.rigidBodies[1].linearMomentum = m * v
  }
  
  var frames: [[Entity]] = []
  for frameID in 0...500 {
    if frameID > 0 {
      system.forceField.positions = system.rigidBodies.flatMap(\.positions)
      system.forceField.velocities = system.rigidBodies.flatMap(\.velocities)
      system.forceField.simulate(time: 0.100)
      system.updateRigidBodies()
    }
    print("frame:", frameID)
    
    let frame = system.createFrame()
    frames.append(frame)
  }
  return frames
}
