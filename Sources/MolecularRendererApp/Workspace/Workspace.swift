import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // TODO:
  // - Design an entirely new CLA system in a single evening.
  return [Entity(position: .zero, type: .atom(.carbon))]
}
