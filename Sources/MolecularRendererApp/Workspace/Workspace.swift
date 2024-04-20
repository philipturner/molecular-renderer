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
  rods.append(propagateUnit.signal[0])
  rods.append(propagateUnit.probe[0]!)
  
  exit(0)
}
