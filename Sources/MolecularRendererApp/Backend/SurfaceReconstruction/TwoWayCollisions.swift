//
//  TwoWayCollisions.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/1/24.
//

import HDL

extension SurfaceReconstruction {
  private enum CollisionState {
    case keep
    case bond
    case oneHydrogen(Int)
  }
  
  mutating func resolveTwoWayCollisions() {
    var updates = [CollisionState?](
      repeating: nil, count: hydrogensToAtomsMap.count)
    
    func withTwoWayCollisions(_ closure: (UInt32, [UInt32]) -> Void) {
      for i in hydrogensToAtomsMap.indices {
        let atomList = hydrogensToAtomsMap[i]
        
        switch atomList.count {
        case 0:
          break
        case 1:
          break
        case 2:
          closure(UInt32(i), atomList)
        case 3:
          fatalError("3-way collision should have been caught.")
        case 4:
          fatalError("4-way collision should have been caught.")
        default:
          fatalError("Too many atoms in collision.")
        }
      }
    }
    
    let orbitals = topology.nonbondingOrbitals()
    for i in orbitals.indices {
      let orbital = orbitals[i]
      if orbital.count == 2 {
        precondition(initialTypeRawValues[i] == 2)
      } else if orbital.count == 1 {
        precondition(initialTypeRawValues[i] == 3)
      } else if orbital.count == 0 {
        precondition(initialTypeRawValues[i] == 4)
      }
    }
    
    withTwoWayCollisions { i, atomList in
      var bridgeheadID: Int = -1
      var sidewallID: Int = -1
      var bothBridgehead = true
      var bothSidewall = true
      for atomID in atomList {
        switch initialTypeRawValues[Int(atomID)] {
        case 2:
          sidewallID = Int(atomID)
          bothBridgehead = false
        case 3:
          bridgeheadID = Int(atomID)
          bothSidewall = false
        default:
          fatalError("This should never happen.")
        }
      }
      
      var linkedList: [Int] = []
      
      if bothBridgehead {
        if atomList.count == 2 {
          let hydrogens = atomsToHydrogensMap[Int(atomList[0])]
          precondition(
            hydrogens.count == 1, "Bridgehead did not have 1 hydrogen.")
          
          linkedList.append(Int(atomList[0]))
          linkedList.append(Int(hydrogens.first!))
          linkedList.append(Int(atomList[1]))
        } else {
          fatalError("Edge case not handled yet.")
        }
      } else if bothSidewall {
      outer:
        for atomID in atomList {
          var hydrogens = atomsToHydrogensMap[Int(atomID)]
          precondition(
            hydrogens.count == 2, "Sidewall did not have 2 hydrogens.")
          
          if hydrogens[0] == UInt32(i) {
            
          } else if hydrogens[1] == UInt32(i) {
            hydrogens = [hydrogens[1], hydrogens[0]]
          } else {
            fatalError("Unexpected hydrogen list.")
          }
          precondition(hydrogens.first! == UInt32(i))
          precondition(hydrogens.last! != UInt32(i))
          
          let nextHydrogen = Int(hydrogens.last!)
          let atomList2 = hydrogensToAtomsMap[nextHydrogen]
          if atomList2.count == 1 {
            // This is the end of the list.
            linkedList.append(Int(atomID))
            linkedList.append(Int(hydrogens.first!))
            precondition(
              hydrogensToAtomsMap[Int(hydrogens.first!)].count == 2)
            var atomListCopy = atomList
            precondition(atomListCopy.count == 2)
            atomListCopy.removeAll(where: { $0 == atomID })
            precondition(atomListCopy.count == 1)
            
            linkedList.append(Int(atomListCopy[0]))
            break outer
          }
        }
        
        if linkedList.count == 0 {
          // Edge case: middle of a bond chain. This is never handled. If there
          // is a self-referential ring, the entire ring is skipped.
          return
        }
        
        precondition(linkedList.count == 3, "Unexpected linked list length.")
      } else {
        precondition(bridgeheadID >= 0 && sidewallID >= 0)
        
        // The IDs of the elements are interleaved. First a carbon, then the
        // connecting collision, then a carbon, then a collision, etc. The end
        // must always be a carbon.
        linkedList.append(bridgeheadID)
        linkedList.append(Int(i))
        linkedList.append(sidewallID)
      }
      
      // Iteratively search through the topology, seeing whether the chain
      // of linked center atoms finally ends.
      var iterationCount = 0
    outer:
      while true {
        defer {
          iterationCount += 1
          if iterationCount > 1000 {
            fatalError(
              "(100) reconstructon took too many iterations to converge.")
          }
        }
        let endOfList = linkedList.last!
        let existingHydrogen = linkedList[linkedList.count - 2]
        
        var hydrogens = atomsToHydrogensMap[endOfList]
        switch hydrogens.count {
        case 1:
          // If this happens, the end of the list is a bridgehead carbon.
          precondition(
            hydrogens[0] == UInt32(existingHydrogen),
            "Unexpected hydrogen list.")
          
          let centerType = initialTypeRawValues[endOfList]
          precondition(centerType == 3, "Must be a bridgehead carbon.")
          break outer
        case 2:
          if hydrogens[0] == UInt32(existingHydrogen) {
            
          } else if hydrogens[1] == UInt32(existingHydrogen) {
            hydrogens = [hydrogens[1], hydrogens[0]]
          } else {
            fatalError("Unexpected hydrogen list.")
          }
          precondition(hydrogens.first! == UInt32(existingHydrogen))
          precondition(hydrogens.last! != UInt32(existingHydrogen))
          
          let nextHydrogen = Int(hydrogens.last!)
          var atomList = hydrogensToAtomsMap[nextHydrogen]
          if atomList.count == 1 {
            // This is the end of the list.
            break outer
          }
          linkedList.append(nextHydrogen)
          precondition(atomList.count == 2) // this may not always be true
          
          precondition(atomList.contains(UInt32(endOfList)))
          atomList.removeAll(where: { $0 == UInt32(endOfList) })
          precondition(atomList.count == 1)
          linkedList.append(Int(atomList[0]))
          
          break
        case 3:
          fatalError("Chain terminated at 3-way collision.")
        default:
          fatalError("Unexpected hydrogen count: \(hydrogens.count)")
        }
      }
      
      for i in linkedList.indices where i % 2 == 1 {
        let listElement = linkedList[i]
        if updates[listElement] == nil {
          if i % 4 == 1 {
            updates[listElement] = .bond
          } else {
            updates[listElement] = .keep
          }
        }
      }
    }
    
    updateCollisions(updates.map { $0 ?? .keep })
  }
  
  private mutating func updateCollisions(_ states: [CollisionState]) {
    var insertedBonds: [SIMD2<UInt32>] = []
    
  outer:
    for i in states.indices {
      precondition(
        i >= 0 && i < hydrogensToAtomsMap.count,
        "Hydrogen index out of bounds.")
      
      switch states[i] {
      case .keep:
        continue outer
      case .bond:
        break
      case .oneHydrogen(_):
        fatalError("This update is not reported yet.")
      }
      
      let atomList = hydrogensToAtomsMap[Int(i)]
      if atomList.count != 2 {
        print("Not a two-way collision: \(atomList)")
      }
      
      precondition(atomList.count == 2, "Not a two-way collision: \(atomList)")
      hydrogensToAtomsMap[Int(i)] = []
      
      let bond = SIMD2(atomList[0], atomList[1])
      insertedBonds.append(bond)
      
      for j in atomList {
        precondition(
          j >= 0 && j < atomsToHydrogensMap.count,
          "Atom index is out of bounds.")
        var previous = atomsToHydrogensMap[Int(j)]
        precondition(previous.count > 0, "Hydrogen map already empty.")
        
        var matchIndex = -1
        for k in previous.indices {
          if previous[k] == UInt32(i) {
            matchIndex = k
            break
          }
        }
        precondition(matchIndex != -1, "Could not find a match.")
        previous.remove(at: matchIndex)
        atomsToHydrogensMap[Int(j)] = previous
      }
    }
    topology.insert(bonds: insertedBonds)
  }
}
