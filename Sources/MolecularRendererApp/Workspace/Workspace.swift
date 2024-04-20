import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Change the main branch to use -Ounchecked by default. Add the new
// surface reconstruction to the branch, but not the serialization (still
// potentially in development).

func createGeometry() -> [MM4RigidBody] {
  let cla = CLA()
  return cla.rigidBodies
}
