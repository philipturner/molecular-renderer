import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Design a system of two gears and two axles, in a stiff housing. Spin the
  // two gears in opposite directions. Determine how many cycles the kinetic
  // energy survives for, at various temperatures.
  return [Entity(position: .zero, type: .atom(.carbon))]
}
