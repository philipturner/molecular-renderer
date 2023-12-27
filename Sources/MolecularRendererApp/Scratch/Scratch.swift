// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

// TODO: Move the code for surface reconstruction into the hardware catalog.
// This keeps it readily accessible without adding a maintenance burden to the
// compiler or MolecularRendererApp.
//
// Location: Materials/Reconstruction

func render100Reconstruction() -> [MRAtom] {
  var lattices: [[Entity]] = []
  lattices.append(latticeBasic100())
  lattices.append(latticeAdvanced100())
  lattices.append(latticeSpherical100())
  
  var topologies = lattices
    .map(reconstruct100(_:))
//  for i in topologies.indices {
//    testTopology(&topologies[i])
//  }
  topologies = topologies
    .map(labelCarbonTypes(_:))
  
  var diamondoid = latticeDiamondoid()
  diamondoid.transform { $0.origin.y -= 3 }
  
  var output: [MRAtom] = []
  output += diamondoid.atoms
  output += topologies[0].atoms.map(MRAtom.init)
  output += topologies[1].atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.x += 3
    return copy
  }
  output += topologies[2].atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.x += 3
    copy.origin.y -= 4.5
    return copy
  }
  return output
}

func reconstruct100(_ atoms: [Entity]) -> Topology {
  var topology = Topology()
  topology.insert(atoms: atoms)
  
  let ccBondMatches = topology.match(topology.atoms)
  var ccBonds: [SIMD2<UInt32>] = []
  for i in topology.atoms.indices {
    for j in ccBondMatches[i] {
      if i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        ccBonds.append(bond)
      }
    }
  }
  topology.insert(bonds: ccBonds)
  cleanupLooseCarbons(&topology, minimumNeighborCount: 1)
  
  regenerateHydrogens(&topology)
  cleanupFourHydrogenCollisions(&topology)
  cleanupThreeHydrogenCollisions(&topology)
  cleanupLooseCarbons(&topology, minimumNeighborCount: 2)
  cleanupLooseCarbons(&topology, minimumNeighborCount: 2)
  nudgeReconstructedCarbons(&topology)
  
  regenerateHydrogens(&topology)
  reconstruct100Chains(&topology)
  nudgeReconstructedCarbons(&topology)
  
  regenerateHydrogens(&topology)
  createHydrogenBonds(&topology)
  return topology
}

struct Reconstruction {
  
}
