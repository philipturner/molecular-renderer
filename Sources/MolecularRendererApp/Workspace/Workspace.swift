import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  // TODO: Investigate the kinetic energies at different keyframes of the cycle.
  let driveSystem = DriveSystem()
  return driveSystem.rigidBodies
}
