import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // TODO: Send the propagate unit back to the original conformation, where
  // three different rods are packed tightly together (and X is bulky).
  //
  // TODO: Recalculate the optimum separations, after refactoring the code.
  // Finding the optimum separation for vertical rods in the propagate unit.
  
  let inputUnit = CLAInputUnit()
  let generateUnit = CLAGenerateUnit()
  let propagateUnit = CLAPropagateUnit()
  
  var rods: [Rod] = []
  rods += inputUnit.rods
  rods += generateUnit.rods
  rods += propagateUnit.rods
  
  return rods.map { $0.rigidBody }
}
