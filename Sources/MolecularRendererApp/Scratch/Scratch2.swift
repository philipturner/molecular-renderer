//
//  Scratch2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/27/23.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

// This may output one of two materials - C or Si. The code handling it must
// function correctly in either case. Being a single element reduces the
// complexity of rules regarding hydrogen locations for detecting collisions.
// It could theoretically be extended to mixed-element structures, but with
// extra effort and restrictions on the code processing the geometry.
func createBeamLattice() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 3 * k + 2 * l }
    Material { .elemental(.carbon) }
  }
  return lattice.atoms
}

extension Reconstruction {
  // Remove malformed and primary carbons.
  mutating func removePathologialAtoms() {
    var iteration = 0
    while true {
      let matches = topology.match(topology.atoms)
      var removedAtoms: [UInt32] = []
      
      for i in topology.atoms.indices {
        let match = matches[i]
        if match.count > 5 {
          fatalError("Unexpected situation: match count > 5")
        } else if match.count > 2 {
          
        } else {
          removedAtoms.append(UInt32(i))
        }
      }
      
      if removedAtoms.count == 0 {
        break
      } else if iteration > 100 {
        fatalError("Primary carbon removal failed after 100 iterations.")
      } else {
        topology.remove(atoms: removedAtoms)
      }
      iteration += 1
    }
  }
  
  // Form all C-C and Si-Si bonds in the lattice interior, assign center types.
  mutating func createBulkAtomBonds() {
    let matches = topology.match(topology.atoms)
    var insertedBonds: [SIMD2<UInt32>] = []
    
    for i in topology.atoms.indices {
      let match = matches[i]
      if match.count > 5 {
        fatalError("Unexpected situation: match count > 5")
      } else if match.count > 2 {
        let centerType = MM4CenterType(rawValue: UInt8(match.count - 1))!
        initialTypes.append(centerType)
        
        for j in match where i < j {
          insertedBonds.append(SIMD2(UInt32(i), j))
        }
      } else {
        fatalError("Pathological atoms should be removed.")
      }
    }
    
    topology.insert(bonds: insertedBonds)
  }
  
  // Next, form the hydrogen bonds. Place hydrogens at the C-C bond length
  // instead of the C-H bond length.
  mutating func createHydrogenSites() {
    precondition(hydrogensToAtomsMap.count == 0, "Map not empty.")
    precondition(atomsToHydrogensMap.count == 0, "Map not empty.")
    atomsToHydrogensMap = Array(repeating: [], count: topology.atoms.count)
    
    // Auto-detect the bond length by querying whether the atom is C or Si.
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    let ccBondLength =
    Element.carbon.covalentRadius + Element.carbon.covalentRadius
    let siSiBondLength =
    Element.silicon.covalentRadius + Element.silicon.covalentRadius
    
    var hydrogenData: [SIMD4<Float>] = []
    
    for i in topology.atoms.indices {
      let atom = topology.atoms[i]
      var bondLength: Float
      switch atom.storage.w {
      case 6: bondLength = ccBondLength
      case 14: bondLength = siSiBondLength
      default: fatalError("Unsupported element.")
      }
      
      for orbital in orbitals[i] {
        let position = atom.position + bondLength * orbital
        let encodedID = Float(bitPattern: UInt32(i))
        hydrogenData.append(SIMD4(position, encodedID))
      }
    }
    
    // Create a transient topology to de-duplicate the hydrogens and merge
    // references between them.
    let hydrogenEntities = hydrogenData.map {
      var storage = $0
      storage.w = 1
      return unsafeBitCast(storage, to: Entity.self)
    }
    var matcher = Topology()
    matcher.insert(atoms: hydrogenEntities)
    let matches = matcher.match(
      hydrogenEntities, algorithm: .absoluteRadius(0.020))
    
  outer:
    for i in hydrogenData.indices {
      let match = matches[i]
      if match.count > 1 {
        for j in match where i != j {
          if i > j {
            continue outer
          }
        }
      }
      
      let hydrogenID = UInt32(hydrogensToAtomsMap.count)
      var atomList: [UInt32] = []
      for j in match {
        let data = hydrogenData[Int(j)]
        let atomID = data.w.bitPattern
        atomList.append(atomID)
      }
      atomList.sort()
      hydrogensToAtomsMap.append(atomList)
      for j in atomList {
        atomsToHydrogensMap[Int(j)].append(hydrogenID)
      }
    }
    
    for j in topology.atoms.indices {
      atomsToHydrogensMap[Int(j)].sort()
    }
  }
}
