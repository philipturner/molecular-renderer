import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // Steps:
  // - 1) Compile the housing without the neck, determine the offset of
  //      the center of mass.
  // - 2) Recompile the housing with the remainder of the structure.
  
  var housing = Housing()
  var flywheel = Flywheel()
  housing.rigidBody.centerOfMass = .zero
  flywheel.rigidBody.centerOfMass = .zero
  flywheel.rigidBody.centerOfMass.z += 1.5
  
  return [housing.rigidBody, flywheel.rigidBody]
}
