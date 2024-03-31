import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// WARNING: The renderer could be in 'MRSceneSize.extreme'. If so, it will not
// render any animations.
func createGeometry() -> [Entity] {
  // TODO: Design a new drive wall for the rods, based on the revised design
  // constraints. Debug the scene with rigid body dynamics. Validate the
  // final design with molecular dynamics on the AMD GPU.
  
  // Compile the geometry.
  let testRod = TestRod()
  let testDriveWall = TestDriveWall()
  var testSystem = TestSystem(
    testDriveWall: testDriveWall, testRod: testRod)
  
  // Move the rigid bodies into position.
  testSystem.testRod.rigidBody.centerOfMass += SIMD3(1.5, 0.5, 1.5)
  testSystem.createForceField()
  
  testSystem.testRod.rigidBody.centerOfMass.x += 10
  testSystem.minimize()
  testSystem.testRod.rigidBody.centerOfMass.x -= 10
  
  return testSystem.createFrame()
}
