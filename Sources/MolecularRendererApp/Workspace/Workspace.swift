import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  var system = DriveSystem()
  system.connectingRod.minimize()
  system.flywheel.minimize()
  system.minimize()
  
  var output: [MM4RigidBody] = []
  output.append(system.connectingRod.rigidBody)
  output.append(system.flywheel.rigidBody)
  output.append(system.housing.rigidBody)
  output.append(system.piston.rigidBody)
  return output
}
