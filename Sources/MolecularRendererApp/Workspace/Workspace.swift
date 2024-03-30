import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// WARNING: The renderer could be in 'MRSceneSize.extreme'. If so, it will not
// render any animations.
func createGeometry() -> [Entity] {
  // Create the housing.
  let testHousing = TestHousing()
  
  // Instantiate the circuit, then select to part to examine.
  let circuit = Circuit()
  let rod = circuit.propagate.broadcast[SIMD2(0, 1)]!
  var testRod = TestRod(rod: rod)
  testRod.rigidBody.centerOfMass.z += 10
  
  // Instantiate the test system.
  var testSystem = TestSystem(testHousing: testHousing, testRod: testRod)
  testSystem.minimize()
  
  return testSystem.createFrame()
}
