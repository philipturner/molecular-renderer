import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  let inputUnit = CLAInputUnit()
  let generateUnit = CLAGenerateUnit()
  
  var rods: [Rod] = []
  rods = [inputUnit.operandA[0]]
  
  let pattern1: HolePattern = { h, k, l in
    Origin { 6 * k }
    Concave {
      Origin { 2 * h + 2 * k }
      Plane { h }
      Plane { k }
      Origin { 4 * h + 4.25 * k }
      Plane { -h }
      Plane { -k }
    }
    Replace { .empty }
  }
  
  var housingDesc = LogicHousingDescriptor()
  housingDesc.dimensions = [6 + 2, 2 * 6 + 2, 5 * 6 + 2]
  housingDesc.patterns = [pattern1]
  let housing = LogicHousing(descriptor: housingDesc)
  
  return rods.map { $0.rigidBody } + [housing.rigidBody]
}
