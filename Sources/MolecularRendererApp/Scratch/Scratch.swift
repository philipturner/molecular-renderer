// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// Recreate C2DonationNH using CBN's benzene geometry, attached to a silicon
// surface. This will be a challenging test of the compiler and how nonbonding
// orbitals can be used to attach atoms. It may also be interesting to see how
// this compiler can facilitate deformation/animation of individual atoms.
//
// In addition, experience using xTB for more advanced analysis:
// - derive structural parameters from simulation data (C-N bond length)
// - perform energy minimizations of the strain from germanium instead of
//   manually adjusting nearby carbons
// - potentially using minimized structures in the middle of the compilation
//   process (e.g. the strained germ-adamantane to more accurately place
//   remaining functional groups)
//
// Estimated completion date: Dec 30, 2023

// TODO:
// - minimize the leg structure in GFN2-xTB
//   - change the NH into NH2 groups
//   - add hydrogens where it will attach to the adamantane
//   - use bond lengths extracted from the results for further compilation
// - minimize the adamantane cage using GFN2-xTB
//   - add sp1-bonded carbons to the top
//   - use the results for further compilation
// - minimize the entire tripod using GFN-FF
//   - change the N-SiH3 into N-H
//   - don't add positional constraints, see whether benzenes stay in position
//   - don't use the results during further compilation; just run the simulation
//     as a sanity check
// - minimize a surface using MM4
//   - passivate all silicons
//   - don't use the results during further compilation; just run the simulation
//     as a sanity check
// - minimize the entire scene using GFN-FF
//   - a silicon atom attached to the tripod can be overlaid on the lattice
//   - using Topology.match(), the closest silicon on the surface will
//     automatically be detected and bonded to the nitrogen
//   - constrain silicon and hydrogen atoms on the boundary
// - save the results
//   - remove hydrogens underneath the surface as a final touch-up
//   - move the compilation code to an HDL unit test
//   - save a screenshot in the hardware catalog, under "adamantanes"
//   - save an XYZ of the atom positions
//   - save a file containing just the simulation code

func createCBNTripod() -> [MRAtom] {
  let leg = CBNTripodLeg()
  let topology = leg.topology
  
  do {
    // Report, then later import from xTB, bond lengths in the molecule. The end
    // result is a structure ready for programmatic linking to the other stuff.
    //
    // We can't use the raw atom positions directly because that is too severe
    // a loss of information. The minimized molecule is asymmetric and may be
    // tilted off-axis by the simulator.
    //
    // Start by scaling the benzene ring according to the new bond lengths.
    // Then, adjust the other atoms' positions relative to the ring. Propagate
    // changes all the way to the methyl and silyl groups, except remove the
    // hydrogens from those groups.
    
    // TODO: - Make a tally similar to the bond record. Then, divide the
    // accumulator by the values from the bond record (except for C-C, which
    // must be separated into 6 sp2 bonds and 1 sp3 bond).
  }
  
  return topology.atoms.map(MRAtom.init)
}


