import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  var housing = Housing()
  var flywheel = Flywheel()
  flywheel.rigidBody.centerOfMass.z += 1.5
  
  return [housing.rigidBody, flywheel.rigidBody]
}
