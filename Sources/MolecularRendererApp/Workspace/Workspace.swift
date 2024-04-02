import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [MM4RigidBody] {
  let housing = Housing()
  var flywheel = Flywheel()
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = flywheel.rigidBody.parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = flywheel.rigidBody.positions
  forceField.minimize()
  
  var rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.parameters = flywheel.rigidBody.parameters
  rigidBodyDesc.positions = forceField.positions
  flywheel.rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  
  var rigidBodies: [MM4RigidBody] = []
  rigidBodies = [housing.rigidBody, flywheel.rigidBody]
  for rigidBodyID in rigidBodies.indices {
    var rigidBody = rigidBodies[rigidBodyID]
    rigidBody.centerOfMass = .zero
    rigidBodies[rigidBodyID] = rigidBody
  }
  return rigidBodies
}
