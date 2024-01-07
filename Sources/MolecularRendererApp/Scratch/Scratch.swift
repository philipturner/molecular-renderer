// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// Unit tests:
// - Get MM4ForceField to the point it can selectively generate parameters. ✅
//   - Disable torsions, hydrogen reductions, and bend-bend forces in the Swift
//     file for 'NCFPart'. ✅
//   - Verify that parameter generation time decreases and the parameters for
//     certain forces are removed. ✅
// - Get MM4ForceField to the point it can produce single-point energies.
//   - Don't worry about optimizing the 'MM4Force' objects to skip
//     initialization or GPU computation; just make them have zero effect.
// - Check the correctness of nonbonded forces w/ hydrogen reductions, making
//   vdW the first correctly functioning force reported on the README.
//   - Compare the instantaneous forces computed from TopologyMinimizer and
//     MM4ForceField without hydrogen reductions.
//   - Evaluate the equilibrium distance with TopologyMinimizer, predict how
//     much hydrogen reductions will shift it.
//   - Run the nonbonded force from MM4ForceField and verify the shift
//     matches TopologyMinimizer.
// - Create the first unit test: a single force evaluation on 'NCFMechanism'.
//   - Only embed vector literals for the 1st part, even in the 2-part system.
//   - Hard-code the expected values of 1 part vs. 2 parts. Create an assertion
//     that in the latter case, values are much greater.
//   - Hard-code the expected values for the 2-part system before and after
//     enabling hydrogen reductions.
// - Test how much the structure shifts when energy-minimized, just simulating
//   a single 'NCFPart'.
//   - The shift ought to be small, but nonzero, resulting in a quick test.
//   - Start with single-point forces, comparing to TopologyMinimizer.
//   - Get MM4ForceField to the point it can do energy minimizations.
//   - Analyze the difference between compiled and minimized structures. Also,
//     the difference between TopologyMinimizer (harmonic angle, no hydrogen
//     reduction) and MM4ForceField (sextic angle, hydrogen reduction).
//   - Measure execution time of the energy minimization, then add a unit test.

func createNCFMechanism() -> [Entity] {
  let mechanism = NCFMechanism(partCount: 2)
  return NCFMechanism.createEntities(
    mechanism.parts.map(\.rigidBody))
}
