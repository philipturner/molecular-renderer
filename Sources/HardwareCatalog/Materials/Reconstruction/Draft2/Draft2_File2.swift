// ALL OF THE IDEAS PRESENTED HERE ARE MIT LICENSED BY PHILIP A. TURNER (2024)
// THEY SHALL NEVER BE PATENTED IN ANY COUNTRY
// THE INVENTOR RESERVES THE RIGHT TO REVOKE A PARTY'S PERMISSION TO USE THESE
// IDEAS, AT HIS DISCRETION, IN RESPONSE TO EGREGIOUS CASES OF MISUSE

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

extension Reconstruction {
  // Remove malformed and primary carbons.
  mutating func removePathologicalAtoms() {
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
      hydrogenEntities, algorithm: .absoluteRadius(0.030))
    
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
  
  mutating func createHydrogenBonds() {
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    func createCenter(_ atomList: [UInt32]) -> SIMD3<Float>? {
      guard atomList.count > 1 else {
        return nil
      }
      var output: SIMD3<Float> = .zero
      for atomID in atomList {
        let atom = topology.atoms[Int(atomID)]
        output += atom.position
      }
      output /= Float(atomList.count)
      return output
    }
    func addBond(_ atomID: Int, orbital: SIMD3<Float>) {
      let atom = topology.atoms[atomID]
      guard case .atom(let element) = atom.type else {
        fatalError("This should never happen.")
      }
      var bondLength = element.covalentRadius
      bondLength += Element.hydrogen.covalentRadius
      let position = atom.position + bondLength * orbital
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      
      let hydrogen = Entity(position: position, type: .atom(.hydrogen))
      let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
      insertedAtoms.append(hydrogen)
      insertedBonds.append(bond)
    }
    func withClosestOrbitals(
      _ atomList: [UInt32],
      _ closure: (UInt32, SIMD3<Float>) -> Void
    ) {
      let siteCenter = createCenter(atomList)!
      for atomID in atomList {
        let orbital = orbitals[Int(atomID)]
        let delta = siteCenter - topology.atoms[Int(atomID)].position
        var keyValuePairs = orbital.map { orbital -> (SIMD3<Float>, Float) in
          (orbital, (orbital * delta).sum())
        }
        keyValuePairs.sort(by: { $0.1 > $1.1 })
        
        let closestOrbital = keyValuePairs[0].0
        closure(atomID, closestOrbital)
      }
    }
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    for i in hydrogensToAtomsMap.indices {
      let atomList = hydrogensToAtomsMap[i]
      
      if atomList.count == 0 {
        // This collision was resolved.
        continue
      } else if atomList.count == 1 {
        let atomID = Int(atomList[0])
        let hydrogenList = atomsToHydrogensMap[atomID]
        let collisionMask = hydrogenList.map {
          let atomList = hydrogensToAtomsMap[Int($0)]
          precondition(atomList.count > 0)
          return atomList.count > 1
        }
        let orbital = orbitals[atomID]
        precondition(orbital.count > 0, "No orbitals.")
        
        // Switch over the different cases of the atom's hydrogen list.
        if hydrogenList.count == 1 {
          precondition(orbital.count == 1, "Unexpected orbital count.")
          
          // Easiest case:
          //
          // The list only has a single hydrogen.
          precondition(!collisionMask[0])
          addBond(atomID, orbital: orbital[orbital.startIndex])
        } else if hydrogenList.count == 2 {
          precondition(orbital.count == 2, "Unexpected orbital count.")
          let orbital0 = orbital[orbital.startIndex]
          let orbital1 = orbital[orbital.endIndex-1]
          
          if collisionMask[0] && collisionMask[1] {
            fatalError("This should never happen.")
          } else if collisionMask[0] || collisionMask[1] {
            // If 1 orbital has a collision:
            //
            // Use a scoring function to match collision(s) to orbitals.
            
            let collisionID =
            (collisionMask[0]) ? hydrogenList[0] : hydrogenList[1]
            let nonCollisionID =
            (collisionMask[0]) ? hydrogenList[1] : hydrogenList[0]
            precondition(collisionID != UInt32(i))
            precondition(nonCollisionID == UInt32(i))
            
            let atomList = hydrogensToAtomsMap[Int(collisionID)]
            let center = createCenter(atomList)!
            let delta = center - topology.atoms[atomID].position
            let score0 = (orbital0 * delta).sum()
            let score1 = (orbital1 * delta).sum()
            
            if score0 > score1 {
              addBond(atomID, orbital: orbital1)
            } else if score0 < score1 {
              addBond(atomID, orbital: orbital0)
            } else {
              fatalError("Scores were equal.")
            }
          } else {
            // If there are 2 orbitals and both are collision-free:
            //
            // The compiler uses a deterministic method to generate orbitals.
            // Plus, the orbitals are already generated once. Assign the first
            // hydrogen in the list to the first orbital.
            let isFirst = hydrogenList[0] == UInt32(i)
            let orbital = isFirst ? orbital0 : orbital1
            addBond(atomID, orbital: orbital)
          }
        } else {
          fatalError("Large hydrogen lists not handled yet.")
        }
      } else if atomList.count == 2 {
        withClosestOrbitals(atomList) { atomID, orbital in
          addBond(Int(atomID), orbital: orbital)
        }
      } else if atomList.count == 3 {
        withClosestOrbitals(atomList) { atomID, orbital in
          addBond(Int(atomID), orbital: orbital)
        }
      } else if atomList.count > 3 {
        fatalError("Edge case with >3 hydrogens in a site not handled yet.")
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
}
