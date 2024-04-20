import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  let cla = CLA()
  
  return cla.rods.map { $0.rigidBody }
}
