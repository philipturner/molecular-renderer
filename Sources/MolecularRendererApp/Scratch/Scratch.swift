// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// TODO: Validate that all 3 structures minimize in OpenMM or xTB.
// - small lonsdaleite shell structure
// - HAbst tripod
// - graphene thiol

func createLonsdaleiteUnitTest() -> [MRAtom] {
  let lattice = createLonsdaleiteLattice()
  
  // MARK: - Bond Formation
  
  var topology = Topology()
  topology.insert(atoms: lattice.atoms)
  do {
    let matches = topology.match(topology.atoms)
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      let match = matches[i]
      for j in match where i < j {
        insertedBonds.append(
          SIMD2(UInt32(i), UInt32(j)))
      }
    }
    topology.insert(bonds: insertedBonds)
    insertedBonds = []
    
    let orbitals = topology.nonbondingOrbitals()
    var insertedAtoms: [Entity] = []
    for i in topology.atoms.indices {
      let atom = topology.atoms[i]
      let bondLength = Element.hydrogen.covalentRadius +
      Element(rawValue: atom.atomicNumber)!.covalentRadius
      
      for orbital in orbitals[i] {
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let position = atom.position + bondLength * orbital
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(
          SIMD2(UInt32(i), UInt32(hydrogenID)))
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // MARK: - Analysis
  
  // Before warping the topology into a shell structure, confirm that it
  // minimizes in OpenMM.
//  minimizeTopology(&topology)
  
  // Minimize the scene topology to determine what the ideal vdW distance is.
  var sceneTopology = createScene(topology)
//  minimizeTopology(&sceneTopology)
  return sceneTopology.atoms.map(MRAtom.init)
}

