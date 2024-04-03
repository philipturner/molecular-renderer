import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // 1) [No mechanosynthesis yet for this video] Show each part materializing
  //    in Morton order, in the state immediately after compilation.
  // 2) Energy-minimize while in the air.
  // 3) Compress down into assembled structure, rotate toward viewer.
  // 4) Run RBD simulation.
  // 5) Revive the GIF encoder.
  
  #if true
  let housing = Housing()
  
  var flywheel = Flywheel()
  let latticeConstant = Constant(.square) { .elemental(.carbon) }
  flywheel.rigidBody.centerOfMass.x += Double(10 * latticeConstant)
  flywheel.rigidBody.centerOfMass.y += Double(10 * latticeConstant)
  flywheel.rigidBody.centerOfMass.z += Double(10.3 * latticeConstant)
  
  var piston = Piston()
  piston.rigidBody.centerOfMass.x += Double(28.5 * latticeConstant)
  piston.rigidBody.centerOfMass.y += Double(10 * latticeConstant)
  piston.rigidBody.centerOfMass.z += Double(10.3 * latticeConstant)
  
  var connectingRod = ConnectingRod()
  connectingRod.rigidBody.centerOfMass.x += Double(-2.6 * latticeConstant)
  connectingRod.rigidBody.centerOfMass.y += Double(10.3 * latticeConstant)
  connectingRod.rigidBody.centerOfMass.z += Double(17.5 * latticeConstant)
  
  func minimize(rigidBody: inout MM4RigidBody) {
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = rigidBody.parameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = rigidBody.positions
    forceField.minimize(tolerance: 0.1)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = rigidBody.parameters
    rigidBodyDesc.positions = forceField.positions
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
  minimize(rigidBody: &flywheel.rigidBody)
  minimize(rigidBody: &piston.rigidBody)
  minimize(rigidBody: &connectingRod.rigidBody)
  
  var rigidBodies: [MM4RigidBody] = []
  rigidBodies.append(housing.rigidBody)
  rigidBodies.append(flywheel.rigidBody)
  rigidBodies.append(piston.rigidBody)
  rigidBodies.append(connectingRod.rigidBody)
  return rigidBodies
  #endif
}
