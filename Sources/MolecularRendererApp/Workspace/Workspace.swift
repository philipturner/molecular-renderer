import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// WARNING: The renderer could be in 'MRSceneSize.extreme'. If so, it will not
// render any animations.
func createGeometry() -> [[Entity]] {
  // TODO: Design a new drive wall for the rods, based on the revised design
  // constraints. Get it tested on the AMD GPU before continuing with
  // patterning the logic rods.
  
  // Compile the geometry.
  let testRod = TestRod()
  let testDriveWall = TestDriveWall()
  var testSystem = TestSystem(
    testDriveWall: testDriveWall, testRod: testRod)
  
  // Move the rigid bodies into position.
  testSystem.testRod.rigidBody.centerOfMass += SIMD3(1.3, 0.5, 1.5)
  testSystem.createForceField()
  
  // Find the initial potential energy.
  print()
  print("potental energy surface:")
  testSystem.minimize(tolerance: 0.1)
  let potentialEnergyOrigin = testSystem.forceField.energy.potential
  
  // Render the scene.
  var frames: [[Entity]] = []
  var displacement: Float = .zero
  for frameID in 0...40 {
    // Spacing between measurements, in nm.
    var stepSize: Float
    if frameID <= 25 {
      stepSize = 0.010
    } else {
      stepSize = 0.250
    }
    
    if frameID > 0 {
      displacement += stepSize
      testSystem.testRod.rigidBody.centerOfMass.x += Double(stepSize)
      testSystem.minimize(tolerance: 0.1)
    }
    frames.append(testSystem.createFrame())
    
    let absoluteEnergy = testSystem.forceField.energy.potential
    let relativeEnergy = absoluteEnergy - potentialEnergyOrigin
    let displacementRepr = String(format: "%.3f", displacement)
    let energyRepr = String(format: "%.1f", relativeEnergy)
    print("U(\(displacementRepr)) = \(energyRepr) zJ")
    if frameID == 25 {
      print("...")
    }
    
    /*
     1 nm cutoff
     U(0.000) = 0.0 zJ
     U(0.010) = -12.3 zJ
     U(0.020) = -21.1 zJ
     U(0.030) = -26.8 zJ
     U(0.040) = -30.0 zJ
     U(0.050) = -30.9 zJ
     U(0.060) = -30.0 zJ
     U(0.070) = -27.5 zJ
     U(0.080) = -23.8 zJ
     U(0.090) = -19.1 zJ
     U(0.100) = -13.7 zJ
     U(0.110) = -7.7 zJ
     U(0.120) = -1.5 zJ
     U(0.130) = 5.0 zJ
     U(0.140) = 11.5 zJ
     U(0.150) = 18.0 zJ
     U(0.160) = 24.4 zJ
     U(0.170) = 30.6 zJ
     U(0.180) = 36.6 zJ
     U(0.190) = 42.3 zJ
     U(0.200) = 47.8 zJ
     U(0.210) = 53.1 zJ
     U(0.220) = 58.1 zJ
     U(0.230) = 62.8 zJ
     U(0.240) = 67.3 zJ
     U(0.250) = 71.5 zJ
     ...
     U(0.500) = 123.3 zJ
     U(0.750) = 133.3 zJ
     U(1.000) = 134.4 zJ
     U(1.250) = 134.4 zJ
     U(1.500) = 134.4 zJ
     U(1.750) = 134.4 zJ
     U(2.000) = 134.4 zJ
     U(2.250) = 134.4 zJ
     U(2.500) = 134.4 zJ
     U(2.750) = 134.4 zJ
     U(3.000) = 134.4 zJ
     U(3.250) = 134.4 zJ
     U(3.500) = 134.4 zJ
     U(3.750) = 134.4 zJ
     U(4.000) = 134.4 zJ
     
     2 nm cutoff
     U(0.000) = 0.0 zJ
     U(0.010) = -11.4 zJ
     U(0.020) = -19.4 zJ
     U(0.030) = -24.3 zJ
     U(0.040) = -26.6 zJ
     U(0.050) = -26.7 zJ
     U(0.060) = -24.9 zJ
     U(0.070) = -21.6 zJ
     U(0.080) = -17.0 zJ
     U(0.090) = -11.5 zJ
     U(0.100) = -5.2 zJ
     U(0.110) = 1.5 zJ
     U(0.120) = 8.6 zJ
     U(0.130) = 15.9 zJ
     U(0.140) = 23.3 zJ
     U(0.150) = 30.6 zJ
     U(0.160) = 37.8 zJ
     U(0.170) = 44.8 zJ
     U(0.180) = 51.6 zJ
     U(0.190) = 58.2 zJ
     U(0.200) = 64.5 zJ
     U(0.210) = 70.5 zJ
     U(0.220) = 76.3 zJ
     U(0.230) = 81.8 zJ
     U(0.240) = 87.0 zJ
     U(0.250) = 92.0 zJ
     ...
     U(0.500) = 160.0 zJ
     U(0.750) = 181.5 zJ
     U(1.000) = 189.7 zJ
     U(1.250) = 193.0 zJ
     U(1.500) = 194.3 zJ
     U(1.750) = 194.8 zJ
     U(2.000) = 194.9 zJ
     U(2.250) = 195.0 zJ
     U(2.500) = 195.0 zJ
     U(2.750) = 195.0 zJ
     U(3.000) = 195.0 zJ
     U(3.250) = 194.9 zJ
     U(3.500) = 194.9 zJ
     U(3.750) = 194.9 zJ
     U(4.000) = 194.9 zJ
     
     3 nm cutoff
     U(0.000) = 0.0 zJ
     U(0.010) = -11.4 zJ
     U(0.020) = -19.3 zJ
     U(0.030) = -24.2 zJ
     U(0.040) = -26.5 zJ
     U(0.050) = -26.5 zJ
     U(0.060) = -24.7 zJ
     U(0.070) = -21.4 zJ
     U(0.080) = -16.8 zJ
     U(0.090) = -11.2 zJ
     U(0.100) = -5.0 zJ
     U(0.110) = 1.8 zJ
     U(0.120) = 9.0 zJ
     U(0.130) = 16.3 zJ
     U(0.140) = 23.6 zJ
     U(0.150) = 31.0 zJ
     U(0.160) = 38.2 zJ
     U(0.170) = 45.3 zJ
     U(0.180) = 52.1 zJ
     U(0.190) = 58.7 zJ
     U(0.200) = 65.0 zJ
     U(0.210) = 71.1 zJ
     U(0.220) = 76.9 zJ
     U(0.230) = 82.4 zJ
     U(0.240) = 87.6 zJ
     U(0.250) = 92.6 zJ
     ...
     U(0.500) = 161.4 zJ
     U(0.750) = 183.8 zJ
     U(1.000) = 192.8 zJ
     U(1.250) = 196.9 zJ
     U(1.500) = 198.8 zJ
     U(1.750) = 199.8 zJ
     U(2.000) = 200.3 zJ
     U(2.250) = 200.6 zJ
     U(2.500) = 200.7 zJ
     U(2.750) = 200.7 zJ
     U(3.000) = 200.7 zJ
     U(3.250) = 200.7 zJ
     U(3.500) = 200.7 zJ
     U(3.750) = 200.7 zJ
     U(4.000) = 200.7 zJ
     */
  }
  return frames
}
