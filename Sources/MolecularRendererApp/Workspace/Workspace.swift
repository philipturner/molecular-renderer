import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let rodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 30 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
  }
  return rodLattice.atoms
}
