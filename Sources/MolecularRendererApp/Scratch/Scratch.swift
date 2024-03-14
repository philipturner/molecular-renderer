// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

// There are four levels of theory:
// - Semiempirical Quantum Mechanics
// - Molecular Mechanics
// - Rigid Body Mechanics
// - Collision Detection
//
// Multiscale simulation enables the design and testing of
// large nanosystems, in full atomic detail.
//
// With only the compute power of a single GPU.

// Create a setup that can test all of the 2-input gates.
// - Use the "Collision Detection" level of theory.
func createGeometry() -> [Entity] {
  let inputRodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 15 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 1.5 * h2k }
      Concave {
        Plane { h2k }
        Origin { 3 * h }
        Plane { -h }
      }
      Concave {
        Plane { h2k }
        Origin { 7 * h }
        Plane { h }
      }
      Replace { .empty }
    }
  }
  
  let outputRodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 25 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 1.5 * h2k }
      Concave {
        Plane { h2k }
        Origin { 3 * h }
        Plane { -h }
      }
      Concave {
        Plane { h2k }
        Origin { 7 * h }
        Plane { h }
        Origin { 7 * h }
        Plane { -h }
      }
      Concave {
        Plane { h2k }
        Origin { 18 * h }
        Plane { h }
      }
      Replace { .empty }
    }
  }
  
  // Set the starting position for the first input rod.
  var atomsInput1 = inputRodLattice.atoms
  for atomID in atomsInput1.indices {
    var atom = atomsInput1[atomID]
    atom.position.y = -atom.position.y
    atom.position.y += 2.0
    atom.position = SIMD3(
      atom.position.z, atom.position.y, atom.position.x)
    atomsInput1[atomID] = atom
  }
  
  
  
  return atomsInput1
}
