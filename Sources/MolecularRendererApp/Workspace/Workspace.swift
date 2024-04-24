import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Design a system of two gears and two axles, in a stiff housing. Spin the
  // two gears in opposite directions. Determine how many cycles the kinetic
  // energy survives for, at various temperatures.
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 16 * h + 12 * k + 12 * l }
    Material { .elemental(.carbon) }
  }
  
  var rotaryPartDesc = RotaryPartDescriptor()
  rotaryPartDesc.cachePath = "/Users/philipturner/Documents/OpenMM/cache/RotaryPart.data"
  let rotaryPart = RotaryPart(descriptor: rotaryPartDesc)
  
  var minimumZ: Float = .greatestFiniteMagnitude
  var maximumZ: Float = -.greatestFiniteMagnitude
  for position in rotaryPart.rigidBody.positions {
    minimumZ = min(minimumZ, position.z)
    maximumZ = max(maximumZ, position.z)
  }
  print(minimumZ)
  print(maximumZ)
  print(maximumZ - minimumZ)
  
  exit(0)
  
}
