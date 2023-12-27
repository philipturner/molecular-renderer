// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer
import Numerics

func render100Reconstruction() -> [MRAtom] {
  var lattices: [[Entity]] = []
  lattices.append(latticeBasic100())
  lattices.append(latticeAdvanced100())
  lattices.append(latticeSpherical100())
  let topologies = lattices
    .map(reconstruct100(_:))
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
  
  let passivatorDirections = topology.nonbondingOrbitals()
  let chBondLength =
  Element.carbon.covalentRadius + Element.hydrogen.covalentRadius
  
  var hydrogens: [Entity] = []
  for i in topology.atoms.indices {
    let carbon = topology.atoms[i]
    for direction in passivatorDirections[i] {
      let position = carbon.position + direction * chBondLength
      let atom = Entity(position: position, type: .atom(.hydrogen))
      hydrogens.append(atom)
    }
  }
  topology.insert(atoms: hydrogens)
  
  // 13498 atoms
  cleanupFourHydrogenCollisions(&topology)
  
  // Clean up all the places where 3 hydrogens collide.
  // - if there's a bridgehead carbon, bond the two sidewalls
  // - if all 3 are sidewalls, generate a new carbon by extrapolating all 3
  //   hydrogen bond deltas to the C-C bond length, then averaging.
  do {
//      var carbonTypesMap = [Int](repeating: -2, count: topology.atoms.count)
//      for i in topology.atoms.indices {
//        if topology.atoms[i].atomicNumber == 1 {
//          // we haven't connected hydrogens yet
//          precondition(atomsToAtomsMap[i].count == 0)
//          carbonTypesMap[i] = -1 // hydrogen type
//        } else {
//          carbonTypesMap[i] = atomsToAtomsMap[i].count
//        }
//      }
//      precondition(carbonTypesMap.allSatisfy { $0 != -2 })
  }
  
  return topology
}
