import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Working on the planetary gear system.

func createGeometry() -> [Entity] {
  return [Entity(position: .zero, type: .atom(.carbon))]
}
