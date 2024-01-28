// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Rewrite the code from scratch, again. This time, debug how the kinetic
  // energy of hydrogen ground-state orbitals is computed.
  // - Don't include the Hartree or exchange terms in the next code rewrite.
  //   Just the kinetic and external energy. Remove SCF iterations as well.
  // - This is still a single-electron system. We need to prove that the
  //   Schrodinger equation produces an orbital strongly reminiscent of the
  //   hydrogen 1s orbital.
  // - Introduce variable-resolution wave functions during this experiment to
  //   reduce the compute cost of high-accuracy tests.
  
  return [Entity(position: .zero, type: .atom(.carbon))]
}
