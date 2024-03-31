import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // TODO: Design a new drive wall for the rods, based on the revised design
  // constraints. Debug the scene with rigid body dynamics. Validate the
  // final design with molecular dynamics on the AMD GPU.
  
  // Save the current code for the CLA to the rod-logic repo, and
  // remove it from the source tree for now. Save the current version of FIRE
  // to "Experiments" in the rod-logic repo.
  //
  // Restart on a new branch. Begin testing logic systems from the ground up,
  // with a systematic approach for every one. RBD (M1 Max), MD (7900 XTX).
  // Establish a pipeline where simulations are serialized and replayed on the
  // Mac.
  
  let rodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 20 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Concave {
        Origin { 1 * h2k }
        Plane { h2k }
        Origin { 1 * h }
        Plane { k - h }
      }
      Replace { .empty }
    }
  }
  return rodLattice.atoms
}
