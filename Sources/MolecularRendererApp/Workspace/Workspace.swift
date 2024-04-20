import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  let inputUnit = CLAInputUnit()
  let generateUnit = CLAGenerateUnit()
  let propagateUnit = CLAPropagateUnit()
  
  var rods: [Rod] = []
  rods += inputUnit.rods
  rods += generateUnit.rods
  rods += propagateUnit.rods
  
  return rods.map { $0.rigidBody }
}
