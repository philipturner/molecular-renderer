import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Design an axle with the required radius, and test whether it retains its
  // kinetic energy for 30 revolutions at 30 GHz. Repeat this process with an
  // auto-generated housing structure.
  return [Entity(position: .zero, type: .atom(.carbon))]
}
