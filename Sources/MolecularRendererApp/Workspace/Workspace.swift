import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Test whether the flywheel and 2-bit half adder work in simulations.

func createGeometry() -> [MM4RigidBody] {
  let connectingRod = ConnectingRod()
  return [connectingRod.rigidBody]
}
