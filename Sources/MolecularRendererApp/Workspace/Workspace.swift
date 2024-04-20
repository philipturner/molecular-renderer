import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  let inputUnit = CLAInputUnit()
  let generateUnit = CLAGenerateUnit()
  
  var rods: [Rod] = []
  rods += inputUnit.rods
  rods += generateUnit.rods
  
  var housingDesc = LogicHousingDescriptor()
  housingDesc.dimensions = SIMD3<Int>(3, 6, 5) &* 6 &+ 2
  housingDesc.patterns = rods.map { $0.createHolePattern() }
  housingDesc.patterns.append { h, k, l in
    Origin { 3 * k }
    Plane { -k }
    Replace { .empty }
  }
  housingDesc.patterns.append { h, k, l in
    Origin { 35 * k }
    Plane { k }
    Replace { .empty }
  }
  let housing = LogicHousing(descriptor: housingDesc)
  
  var output: [MM4RigidBody] = []
  output += rods.map { $0.rigidBody }
  output.append(housing.rigidBody)
  return output
}
