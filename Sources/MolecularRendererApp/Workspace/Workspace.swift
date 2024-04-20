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
  return rods.map { $0.rigidBody }
}
