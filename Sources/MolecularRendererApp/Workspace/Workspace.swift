import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  let driveSystem = DriveSystem()
  let connectingRod = driveSystem.connectingRod
  let flywheel = driveSystem.flywheel
  let housing = driveSystem.housing
  let piston = driveSystem.piston
  
  var forceFieldParameters = connectingRod.rigidBody.parameters
  forceFieldParameters.append(contentsOf: flywheel.rigidBody.parameters)
  forceFieldParameters.append(contentsOf: housing.rigidBody.parameters)
  forceFieldParameters.append(contentsOf: piston.rigidBody.parameters)
  
  var forceFieldPositions = connectingRod.rigidBody.positions
  forceFieldPositions += flywheel.rigidBody.positions
  forceFieldPositions += housing.rigidBody.positions
  forceFieldPositions += piston.rigidBody.positions
  
  return driveSystem.rigidBodies
}
