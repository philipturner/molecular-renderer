import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Task:
// - Design a revised system using polygonal bearings. Etch out a circular mask
//   using the compiler. Cap the knobs to prevent part separation at 2 GHz.

func createGeometry() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 300 * h + 6 * k + 6 * l }
    Material { .elemental(.carbon) }
  }
  
  var atoms = lattice.atoms
  for atomID in atoms.indices {
    var atom = atoms[atomID]
    atom.position -= SIMD3(1, 1, 1)
    atoms[atomID] = atom
  }
  
  let serialized = Serialization.serialize(atoms: atoms)
  let deserialized = Serialization.deserialize(atoms: serialized)
  
  return atoms + deserialized
}
