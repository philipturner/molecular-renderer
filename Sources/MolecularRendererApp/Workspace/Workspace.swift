import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  
  // Diamond:
  //
  // 8000 atoms:
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * (h + k + l) }
    Material { .elemental(.carbon) }
  }
  
  return lattice.atoms
}
