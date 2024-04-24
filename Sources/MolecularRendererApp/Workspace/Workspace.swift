import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  return [Entity(position: .zero, type: .atom(.carbon))]
}
