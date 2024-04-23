import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  var descriptor = RotaryPartDescriptor()
  descriptor.cachePath =
  "/Users/philipturner/Documents/OpenMM/cache/RotaryPart.data"
  
  var part = RotaryPart(descriptor: descriptor)
  
  var atoms: [Entity] = []
  let parameters = part.rigidBody.parameters
  for atomID in parameters.atoms.indices {
    let atomicNumber = parameters.atoms.atomicNumbers[atomID]
    let position = part.rigidBody.positions[atomID]
    let storage = SIMD4(position, Float(atomicNumber))
    let atom = Entity(storage: storage)
    atoms.append(atom)
  }
  
  return atoms
}
