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
  
  for markerID in 0..<5 {
    var atom = Entity(position: .zero, type: .atom(.oxygen))
    
    let θ = 2 * Float.pi * Float(markerID) / 5
    var r = Float(1.33)
    atom.position.x = r * Float.cos(θ)
    atom.position.y = r * Float.sin(θ)
    atoms.append(atom)
    
    r = Float(2.73)
    atom.position.x = r * Float.cos(θ)
    atom.position.y = r * Float.sin(θ)
    atoms.append(atom)
  }
  
  return atoms
}
