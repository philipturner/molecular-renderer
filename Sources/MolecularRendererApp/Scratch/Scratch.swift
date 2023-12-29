// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// Recreate C2DonationNH using CBN's benzene geometry, attached to a silicon
// surface. This will be a challenging test of the compiler and how nonbonding
// orbitals can be used to attach atoms.
//
// One combined image:
// - left: render of CBN tripod on surface
//   - energy-minimized with GFN-FF
// - right: graph of tripod from patent
//
// Estimate for completion: evening Dec 29, 2024

func createCBNTripod() -> [MRAtom] {
  let legLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 4 * h + 3 * h2k + 1 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 0.25 * l }
        Plane { l }
      }
      Replace { .empty }
      
      // TODO: Change these selective volumes to highlight some fluorines and
      // nitrogens.
      Volume {
        Convex {
          Origin { 2 * h }
          Plane { h }
        }
        Replace { .atom(.fluorine) }
      }
      Volume {
        Convex {
          Origin { 1 * h }
          Plane { -h }
        }
        Replace { .atom(.nitrogen) }
      }
    }
  }
  
  var legTopology = Topology()
  legTopology.atoms = legLattice.atoms
  
  do {
    var grapheneHexagonScale: Float
    
    // Convert graphene lattice constant from Å to nm.
    let grapheneConstant: Float = 2.45 / 10
    
    // Retrieve lonsdaleite lattice constant in nm.
    let lonsdaleiteConstant = Constant(.hexagon) { .elemental(.carbon) }
    
    // Each hexagon's current side length is the value of
    // `lonsdaleiteConstant`. Dividing by this constant, changes the hexagon
    // so its sides are all 1 nm.
    grapheneHexagonScale = 1 / lonsdaleiteConstant
    
    // Multiply by the graphene constant. This second transformation stretches
    // the hexagon, so its sides are all 0.245 nm.
    grapheneHexagonScale *= grapheneConstant
    
    for atomID in legTopology.atoms.indices {
      // Flatten the sp3 sheet into an sp2 sheet.
      legTopology.atoms[atomID].position.z = 0
      
      // Resize the hexagon side length, so it matches graphene.
      legTopology.atoms[atomID].position.x *= grapheneHexagonScale
      legTopology.atoms[atomID].position.y *= grapheneHexagonScale
    }
  }
  
  do {
    // Graphene's covalent bond length is 1.42 Å.
    let covalentBondLength: Float = 1.42 / 10
    let matches = legTopology.match(
      legTopology.atoms,
      algorithm: .absoluteRadius(covalentBondLength * 1.01))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in legTopology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    legTopology.insert(bonds: insertedBonds)
  }
  
  do {
    // TODO: Estimate bond lengths between the relevant atoms from literature.
  }
  
  return legTopology.atoms.map(MRAtom.init)
}
