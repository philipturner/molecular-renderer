import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Rods (show skeleton of 2-bit HA)
// Patterns (show one rod in detail)
// Drive walls (show before and after actuation)
// Housing (show housing and drive walls, without logic rods inside)
//
// Upload images to GDrive

func createGeometry() -> [MM4RigidBody] {
  let halfAdder = HalfAdder()
  var rigidBodies = halfAdder.rigidBodies
  
  // Create a setup for taking multiple similar images, which don't shift due
  // to user movements.
  for rigidBodyID in rigidBodies.indices {
    var rigidBody = rigidBodies[rigidBodyID]
    
    let angle: Double = .pi / 2
    let axis: SIMD3<Double> = [1, 0, 0]
    rigidBody.rotate(angle: angle, axis: axis)
    
    let rotation = Quaternion(angle: angle, axis: axis)
    var centerOfMass = rigidBody.centerOfMass
    centerOfMass = rotation.act(on: centerOfMass)
    rigidBody.centerOfMass = centerOfMass
    
    rigidBody.centerOfMass += SIMD3(-5, 1.5, -28)
    
    rigidBodies[rigidBodyID] = rigidBody
  }
  
  return rigidBodies
}
