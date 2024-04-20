import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  let inputUnit = CLAInputUnit()
  let generateUnit = CLAGenerateUnit()
  
  let rod = inputUnit.operandA[0]
  let rigidBody = rod.rigidBody
  
  var housingDesc = LogicHousingDescriptor()
  housingDesc.dimensions = [6 + 2, 2 * 6 + 2, 5 * 6 + 2]
  housingDesc.patterns = [rod.createHolePattern()]
  let housing = LogicHousing(descriptor: housingDesc)
  
  return [rod.rigidBody, housing.rigidBody]
}
