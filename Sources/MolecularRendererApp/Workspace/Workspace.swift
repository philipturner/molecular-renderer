import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  let lattice = ConnectingRod.createLattice()
  return lattice.atoms
  
//  var flywheel = Flywheel()
//  
//  var forceFieldDesc = MM4ForceFieldDescriptor()
//  forceFieldDesc.parameters = flywheel.rigidBody.parameters
//  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
//  forceField.positions = flywheel.rigidBody.positions
//  forceField.minimize(tolerance: 0.1)
//  
//  var rigidBodyDesc = MM4RigidBodyDescriptor()
//  rigidBodyDesc.parameters = flywheel.rigidBody.parameters
//  rigidBodyDesc.positions = forceField.positions
//  flywheel.rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
//  
//  return [flywheel.rigidBody]
  
  #if false
  let housing = Housing()
  
  var flywheel = Flywheel()
  let latticeConstant = Constant(.square) { .elemental(.carbon) }
  flywheel.rigidBody.centerOfMass.x += Double(10 * latticeConstant)
  flywheel.rigidBody.centerOfMass.y += Double(10 * latticeConstant)
  flywheel.rigidBody.centerOfMass.z += Double(10.3 * latticeConstant)
  
  var piston = Piston()
  piston.rigidBody.centerOfMass.x += Double(29 * latticeConstant)
  piston.rigidBody.centerOfMass.y += Double(10 * latticeConstant)
  piston.rigidBody.centerOfMass.z += Double(10.3 * latticeConstant)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = flywheel.rigidBody.parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = flywheel.rigidBody.positions
  forceField.minimize(tolerance: 0.1)
  
  var rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.parameters = flywheel.rigidBody.parameters
  rigidBodyDesc.positions = forceField.positions
  flywheel.rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  
  var rigidBodies: [MM4RigidBody] = []
  rigidBodies.append(housing.rigidBody)
  rigidBodies.append(flywheel.rigidBody)
  rigidBodies.append(piston.rigidBody)
  return rigidBodies
  #endif
}
