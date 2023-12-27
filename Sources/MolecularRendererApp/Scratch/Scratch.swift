// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

func createReconstructionDemo() -> [MRAtom] {
  let lattice = createBeamLattice()
  var topology = Topology()
  topology.insert(atoms: lattice)
  
  var reconstruction = Reconstruction()
  reconstruction.topology = topology
  reconstruction.prepare()
  
  do {
    var updates: [Reconstruction.CollisionState?] = []
    for _ in reconstruction.hydrogensToAtomsMap.indices {
      updates.append(nil)
    }
    
    func withTwoWayCollisions(_ closure: (UInt32, [UInt32]) -> Void) {
      for i in reconstruction.hydrogensToAtomsMap.indices {
        let atomList = reconstruction.hydrogensToAtomsMap[i]
        if atomList.count > 2 {
          fatalError("3-way collisions not handled yet.")
        }
        if atomList.count < 2 {
          continue
        }
        closure(UInt32(i), atomList)
      }
    }
    
    withTwoWayCollisions { i, atomList in
      var bridgeheadID: Int = -1
      var sidewallID: Int = -1
      var bothBridgehead = true
      var bothSidewall = true
      for atomID in atomList {
        switch reconstruction.initialTypes[Int(atomID)] {
        case .secondary:
          sidewallID = Int(atomID)
          bothBridgehead = false
        case .tertiary:
          bridgeheadID = Int(atomID)
          bothSidewall = false
        default:
          fatalError("This should never happen.")
        }
      }
      
      if bothBridgehead {
        fatalError("Edge case not handled yet.")
      }
      if bothSidewall {
        // This will be necessary to reconstruct many surfaces. For now, don't
        // handle the edge case.
        return
      }
      precondition(bridgeheadID >= 0 && sidewallID >= 0)
      
      // The IDs of the elements are interleaved. First a carbon, then the
      // connecting collision, then a carbon, then a collision, etc. The end
      // must always be a carbon.
      var linkedList: [Int] = []
      linkedList.append(bridgeheadID)
      linkedList.append(Int(i))
      linkedList.append(sidewallID)
      
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
        
        var hydrogens = reconstruction.atomsToHydrogensMap[endOfList]
        switch hydrogens.count {
        case 1:
          print("case 1")
          precondition(
            hydrogens[0] == UInt32(existingHydrogen),
            "Unexpected hydrogen list.")
          fatalError("This should have been caught in a previous iteration.")
        case 2:
          print("case 2")
          if hydrogens[0] == UInt32(existingHydrogen) {
            
          } else if hydrogens[1] == UInt32(existingHydrogen) {
            hydrogens = [hydrogens[1], hydrogens[0]]
          } else {
            fatalError("Unexpected hydrogen list.")
          }
          precondition(hydrogens.first! == UInt32(existingHydrogen))
          precondition(hydrogens.last! != UInt32(existingHydrogen))
          
          let nextHydrogen = Int(hydrogens.last!)
          var atomList = reconstruction.hydrogensToAtomsMap[nextHydrogen]
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
          print("case 3")
          fatalError("3-way collisions not handled yet.")
        default:
          print("case default")
          fatalError("Unexpected hydrogen count: \(hydrogens.count)")
        }
      }
      print(linkedList)
    }
    
    reconstruction.updateCollisions(updates.map { $0 ?? .keep })
  }
  
  reconstruction.apply()
  topology = reconstruction.topology
  
  return topology.atoms.map(MRAtom.init)
}

// This may output one of two materials - C or Si. The code handling it must
// function correctly in either case. Being a single element reduces the
// complexity of rules regarding hydrogen locations for detecting collisions.
// It could theoretically be extended to mixed-element structures, but with
// extra effort and restrictions on the code processing the geometry.
func createBeamLattice() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 3 * k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      // These two cuts can be commented out to see how the structure warps
      // differently without them.
      Convex {
        Origin { 1.5 * k + 1.75 * l }
        Concave {
          Plane { k }
          Plane { l }
        }
      }
      Convex {
        Origin { 1.5 * k + 0.25 * l }
        Concave {
          Plane { -k }
          Plane { -l }
        }
      }
      Replace { .empty }
    }
  }
  return lattice.atoms
}
