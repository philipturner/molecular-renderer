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
// Estimated completion date: Dec 30-31, 2023 ✅

// Tasks:
// - minimize the leg structure in GFN2-xTB ✅
//   - change the NH into NH2 groups ✅
//   - add hydrogens where it will attach to the adamantane ✅
//   - use bond lengths extracted from the results for further compilation ✅
// - minimize the adamantane cage using GFN2-xTB ✅
//   - add sp1-bonded carbons to the top ✅
//   - use the results for further compilation ✅
// - minimize the entire tripod using GFN-FF ✅
//   - change the N-SiH3 into N-H ✅
//   - don't add positional constraints, see whether benzenes stay in position ✅
//   - don't use the results during further compilation; just run the simulation
//     as a sanity check ❌
// - minimize a surface using GFN-FF ❌
//   - passivate all silicons ❌
//   - use the results to adjust the Si-Si and Si-H bond lengths before
//     constraining the ends of the lattice ❌
// - minimize the entire scene using GFN-FF ❌
//   - a silicon atom attached to the tripod can be overlaid on the lattice ❌
//   - using Topology.match(), the closest silicon on the surface will
//     automatically be detected and bonded to the nitrogen ❌
//   - constrain silicon and hydrogen atoms on the boundary ❌
//     - try using ONIOM, so the tripod is still optimized with QM ❌
// - save the results
//   - remove hydrogens underneath the surface as a final touch-up ❌
//   - save all of the code in "Materials/CBNTripod" ✅
//   - save a screenshot ✅
//   - copy portions of the code into an HDL unit test ✅
//     - figure out how to disable whole-module optimization in unit tests
//       (provides a more realistic performance estimate b/c MR also disables
//        whole-module optimization) ✅

func createCBNTripod() -> [MRAtom] {
  var tripod = CBNTripod()
  var output: [Entity] = []
  
  tripod.setTripodStructure(CBNTripod.xtbOptimizedStructure2)
  output += tripod.createAtoms().map {
    var copy = $0
    copy.position.x += 0
    return copy
  }
  
  tripod.passivateNHGroups(.silicon)
  tripod.rotateLegs(slantAngleDegrees: 0, swingAngleDegrees: 0)
  output += tripod.createAtoms().map {
    var copy = $0
    copy.position += 1.5 * SIMD3(0.86, 0, 0.5)
    return copy
  }
  
  return output.map(MRAtom.init)
  
  // Activate various lines of code here to execute the xTB simulation workflow.
//  let process = XTBProcess(path: "/Users/philipturner/Desktop/xtb")
//  let encoded = process.readFile(name: "xtbopt.coord")
//  let atoms = try! process.decodeAtoms(encoded, encoding: .xtb)
//  let atoms = tripod.createAtoms()
//  let encoded = try! process.encodeAtoms(atoms)
//  process.writeFile(name: "coord", encoded)
//  print(try! process.encodeAtoms(atoms, encoding: .hdl))
}

extension CBNTripod {
  // Only set the coordinates for the atoms in the tripod, not the surface.
  mutating func setTripodStructure(_ atoms: [Entity]) {
    var cursor = 0
    do {
      var topology = cage.topology
      for i in topology.atoms.indices {
        topology.atoms[i] = atoms[cursor]
        cursor += 1
      }
      cage.topology = topology
    }
    for legID in 0..<3 {
      var topology = legs[legID].topology
      for i in topology.atoms.indices {
        topology.atoms[i] = atoms[cursor]
        cursor += 1
      }
      legs[legID].topology = topology
    }
  }
}
