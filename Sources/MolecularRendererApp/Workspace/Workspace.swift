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
  
  var rods: [Rod] = []
  rods.append(halfAdder.inputUnit.operandA[0])
  rods.append(halfAdder.intermediateUnit.propagate[0])

  rods[0].rigidBody.rotate(angle: .pi / 2, axis: [0, 1, 0])
  rods[1].rigidBody.rotate(angle: .pi, axis: [0, 1, 0])
  rods[1].rigidBody.centerOfMass += SIMD3(-0.9, 0.8, 1.3)
  
  return rods.map(\.rigidBody)
}
