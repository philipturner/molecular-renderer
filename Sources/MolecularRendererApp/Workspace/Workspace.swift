import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [[MM4RigidBody]] {
  var driveSystem = DriveSystem()
  driveSystem.minimize()
  driveSystem.setVelocitiesToTemperature(2 * 298)
  
  // [0] = connectingRod
  // [1] = flywheel
  // [2] = housing
  // [3] = piston
  var rigidBodies = driveSystem.rigidBodies
  
  var forceFieldParameters = rigidBodies[0].parameters
  var forceFieldPositions = rigidBodies[0].positions
  var forceFieldVelocities = rigidBodies[0].velocities
  for rigidBody in rigidBodies[1...] {
    forceFieldParameters.append(contentsOf: rigidBody.parameters)
    forceFieldPositions.append(contentsOf: rigidBody.positions)
    forceFieldVelocities.append(contentsOf: rigidBody.velocities)
  }
  
  
}
