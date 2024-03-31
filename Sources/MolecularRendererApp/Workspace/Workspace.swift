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
  testSystem.testRod.rigidBody.centerOfMass += SIMD3(10.3, 0.5, 1.5)
  testSystem.createForceField()
  
  // Find the initial potential energy.
  print()
  print("potental energy surface:")
  testSystem.minimize(tolerance: 0.1)
  let potentialEnergyOrigin = testSystem.forceField.energy.potential
  
  testSystem.testRod.rigidBody.centerOfMass += SIMD3(-10, 0, 0)
  
  // Render the scene.
  var frames: [[Entity]] = []
  var displacement: Float = .zero
  for frameID in 0...50 {
    // Spacing between measurements, in nm.
    var stepSize: Float
    if frameID <= 35 {
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
    
    #if true
    print("U(\(displacementRepr)) = \(energyRepr) zJ")
    if frameID == 35 {
      print("...")
    }
    #else
    print(displacementRepr, energyRepr)
    #endif
    
    /*
     S terminated
     U(-0.090) = 347.7 zJ
     U(-0.080) = 280.8 zJ
     U(-0.070) = 222.3 zJ
     U(-0.060) = 171.5 zJ
     U(-0.050) = 128.0 zJ
     U(-0.040) = 91.1 zJ
     U(-0.030) = 60.4 zJ
     U(-0.020) = 35.4 zJ
     U(-0.010) = 15.4 zJ
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
     
     H terminated
     U(-0.090) = 147.6 zJ
     U(-0.080) = 111.5 zJ
     U(-0.070) = 81.8 zJ
     U(-0.060) = 57.7 zJ
     U(-0.050) = 38.7 zJ
     U(-0.040) = 24.1 zJ
     U(-0.030) = 13.3 zJ
     U(-0.020) = 6.1 zJ
     U(-0.010) = 1.7 zJ
     U(0.000) = 0.0 zJ
     U(0.010) = 0.4 zJ
     U(0.020) = 2.7 zJ
     U(0.030) = 6.5 zJ
     U(0.040) = 11.4 zJ
     U(0.050) = 17.3 zJ
     U(0.060) = 23.9 zJ
     U(0.070) = 30.9 zJ
     U(0.080) = 38.3 zJ
     U(0.090) = 45.8 zJ
     U(0.100) = 53.3 zJ
     U(0.110) = 60.7 zJ
     U(0.120) = 68.0 zJ
     U(0.130) = 75.1 zJ
     U(0.140) = 82.0 zJ
     U(0.150) = 88.6 zJ
     U(0.160) = 95.0 zJ
     U(0.170) = 101.0 zJ
     U(0.180) = 106.8 zJ
     U(0.190) = 112.3 zJ
     U(0.200) = 117.5 zJ
     U(0.210) = 122.4 zJ
     U(0.220) = 127.1 zJ
     U(0.230) = 131.5 zJ
     U(0.240) = 135.7 zJ
     U(0.250) = 139.7 zJ
     ...
     U(0.500) = 194.6 zJ
     U(0.750) = 212.6 zJ
     U(1.000) = 219.6 zJ
     U(1.250) = 222.4 zJ
     U(1.500) = 223.6 zJ
     U(1.750) = 223.9 zJ
     U(2.000) = 224.0 zJ
     U(2.250) = 224.1 zJ
     U(2.500) = 224.1 zJ
     U(2.750) = 224.1 zJ
     U(3.000) = 224.1 zJ
     U(3.250) = 224.1 zJ
     U(3.500) = 224.1 zJ
     U(3.750) = 224.1 zJ
     U(4.000) = 224.1 zJ
     */
  }
  return frames
}
