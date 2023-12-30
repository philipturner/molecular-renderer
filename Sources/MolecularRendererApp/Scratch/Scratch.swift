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
// - derive structural parameters from simulation data (C-N bond length) ✅
// - perform energy minimizations of the strain from germanium instead of
//   manually adjusting nearby carbons ❌
// - potentially using minimized structures in the middle of the compilation
//   process (e.g. the strained germ-adamantane to more accurately place
//   remaining functional groups) ✅
//
// Estimated completion date: Dec 30-31, 2023

// Tasks:
// - minimize the leg structure in GFN2-xTB ✅
//   - change the NH into NH2 groups ✅
//   - add hydrogens where it will attach to the adamantane ✅
//   - use bond lengths extracted from the results for further compilation ✅
// - minimize the adamantane cage using GFN2-xTB ✅
//   - add sp1-bonded carbons to the top ✅
//   - use the results for further compilation ✅
// - minimize the entire tripod using GFN-FF
//   - change the N-SiH3 into N-H
//   - don't add positional constraints, see whether benzenes stay in position
//   - don't use the results during further compilation; just run the simulation
//     as a sanity check
// - minimize a surface using GFN-FF
//   - passivate all silicons
//   - use the results to adjust the Si-Si and Si-H bond lengths before
//     constraining the ends of the lattice
// - minimize the entire scene using GFN-FF
//   - a silicon atom attached to the tripod can be overlaid on the lattice
//   - using Topology.match(), the closest silicon on the surface will
//     automatically be detected and bonded to the nitrogen
//   - constrain silicon and hydrogen atoms on the boundary
// - save the results
//   - remove hydrogens underneath the surface as a final touch-up
//   - save all of the code in "Materials/CBNTripod"
//   - save a screenshot
//   - copy portions of the code into an HDL unit test

func createCBNTripod() -> [MRAtom] {
  let cage = CBNTripodCage()
  let topology = cage.topology
  return topology.atoms.map(MRAtom.init)
}

extension CBNTripodCage {
  // Replace the atom positions with the energy-minimized ones from xTB.
  mutating func compilationPass5() {
    let xtbOptimizedAtoms: [Entity] = [
      Entity(position: SIMD3( 0.0000, -0.2471, -0.1449), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.1255, -0.2471,  0.0725), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.1255, -0.2471,  0.0725), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.0000, -0.2024,  0.1490), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.0000, -0.0523,  0.1782), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.1290, -0.2024, -0.0745), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.1543, -0.0523, -0.0891), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.1290, -0.2024, -0.0745), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.1543, -0.0523, -0.0891), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.0000,  0.0341,  0.0000), type: .atom(.germanium)),
      Entity(position: SIMD3( 0.0000, -0.2795,  0.2808), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.0000, -0.3987,  0.2894), type: .atom(.oxygen)),
      Entity(position: SIMD3( 0.0000, -0.2153,  0.3710), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.2431, -0.2795, -0.1404), type: .atom(.carbon)),
      Entity(position: SIMD3( 0.2506, -0.3987, -0.1447), type: .atom(.oxygen)),
      Entity(position: SIMD3( 0.3213, -0.2153, -0.1856), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.2431, -0.2795, -0.1404), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.2506, -0.3987, -0.1447), type: .atom(.oxygen)),
      Entity(position: SIMD3(-0.3213, -0.2153, -0.1856), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.0000, -0.3563, -0.1495), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.0000, -0.2088, -0.2475), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.2143, -0.2088,  0.1237), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.1295, -0.3563,  0.0748), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.1295, -0.3563,  0.0748), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.2143, -0.2088,  0.1237), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.0880, -0.0254,  0.2368), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.0880, -0.0254,  0.2368), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.1610, -0.0254, -0.1946), type: .atom(.hydrogen)),
      Entity(position: SIMD3( 0.2490, -0.0254, -0.0422), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.2490, -0.0254, -0.0422), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.1610, -0.0254, -0.1946), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.0000,  0.2273, -0.0000), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.0000,  0.3471, -0.0000), type: .atom(.carbon)),
    ]
    
    topology.atoms = xtbOptimizedAtoms
  }
}
