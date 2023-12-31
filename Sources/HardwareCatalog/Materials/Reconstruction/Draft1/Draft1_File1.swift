// ALL OF THE IDEAS PRESENTED HERE ARE MIT LICENSED BY PHILIP A. TURNER (2024)
// THEY SHALL NEVER BE PATENTED IN ANY COUNTRY
// THE INVENTOR RESERVES THE RIGHT TO REVOKE A PARTY'S PERMISSION TO USE THESE
// IDEAS, AT HIS DISCRETION, IN RESPONSE TO EGREGIOUS CASES OF MISUSE

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

// Move the code for surface reconstruction into the hardware catalog.
// This keeps it readily accessible without adding a maintenance burden to the
// compiler or MolecularRendererApp.
//
// Location: Reconstruction/Draft1
//
// Lucrative use case:
// - selectively avoid reconstruction of an entire side, or force every single
//   carbon in a chain to reconstruct
//   - requires information about collisions to be generated prior to warping,
//     then applied after warping
//   - make the record of collisions adapt to atom/bond removals?
// - this is a highly controllable method to fine-tune the inherent strain on
//   a crystal face
// - same effect as locally expanding the lattice constant
// - viable method to create small curved shell structures without Si doping
//   - use a beam curved through surface strain as the exemplary structure to
//     model during development
//
// Ideas for second design iteration:
// - more elaborate rules and relationships based on a simple concept:
//     2/3/4-hydrogen collision sites
//     - more deterministic results; postpone the loss of information
//     - only a single match() operation
//     - more potential for deferring edge-case behavior to the user
// - applicable to more than just diamond (100)
//   - the strange issues that appear when cutting lonsdaleite in certain ways
//   - such cuts for lonsdaleite may be highly desirable
// - applicable to silicon and other materials
//   - find a more extensible approach for applying nudges
// - flexibility to keep primary carbons around and form bonds with them
//
// Design space restricton to simplify the compiler:
// - no isolated enclosed shells
//   - a small number of warped parts that interlock to provide something
//     close-enough to a strained shell structure
// - compiler doesn't need to preserve hydrogen collision sites across any
//   merging operations
//   - less complex graphs; unidirectional and acyclic
// - adheres to the workflow acceleration of breaking into smaller parts
//   - more manufacturable
//   - more recyclable

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
