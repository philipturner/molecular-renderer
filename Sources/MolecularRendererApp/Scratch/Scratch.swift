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
  //
  // Procedure:
  // - Take an exact numerical integral at the finest possible grid width,
  //   create a mipmap, then resample at the centers of bins. Certain density
  //   thresholds will fail to be sampled.
  // - Find how deviation from true energy scales with uniform grid width or
  //   variable fragment count. Compare density threshold and minimum
  //   fragment size iso-accuracy.
  // - Compare constrained fragment count (density threshold) to actual fragment
  //   count, which will be larger.
  
  return [Entity(position: .zero, type: .atom(.carbon))]
}
