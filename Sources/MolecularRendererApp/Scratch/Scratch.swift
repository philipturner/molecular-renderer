// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createNanoRobot() -> [Entity] {
  let finger = RobotFinger()
  return finger.topology.atoms
}

struct RobotFinger {
  var topology = Topology()
  
  init() {
    compilationPass0()
  }
  
  mutating func compilationPass0() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 6 * h + 5 * h2k + 3 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 0.5 * l }
          Plane { -l }
        }
        Convex {
          Origin { 4 * h + h2k }
          Plane { -k - 2 * h }
        }
        Convex {
          Origin { 0.0 * h2k }
          Plane { -h2k }
        }
        Convex {
          Origin { 2.25 * l }
          Plane { l }
        }
        
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
}
