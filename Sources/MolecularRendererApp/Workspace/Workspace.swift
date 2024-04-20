import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // TODO: Send the propagate unit back to the original conformation, where
  // three different rods are packed tightly together (and X is bulky).
  // TODO: Recalculate the optimum separations, after refactoring the code.
  
  let inputUnit = CLAInputUnit()
  let generateUnit = CLAGenerateUnit()
//  let propagateUnit = CLAPropagateUnit()
  
  var rods: [Rod] = []
  rods += inputUnit.rods
  rods += generateUnit.rods
//  rods += propagateUnit.rods
  
//  rods.append(propagateUnit.signal[0])
  
  return rods.map { $0.rigidBody }
}
