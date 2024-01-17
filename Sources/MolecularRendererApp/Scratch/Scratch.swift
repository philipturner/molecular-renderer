// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 10 * k + 10 * l }
    Material { .elemental(.carbon) }
    
//    Volume {
//      Origin { 5 * (h + k + l) }
//      Plane { h }
//      Plane { k }
//      Plane { l }
//      Replace { .empty }
//    }
  }
  var topology = Topology()
  topology.insert(atoms: lattice.atoms)
  var reconstruction = SurfaceReconstruction()
  reconstruction.material = .elemental(.carbon)
  reconstruction.topology = topology
  reconstruction.removePathologicalAtoms()
  reconstruction.createBulkAtomBonds()
  reconstruction.createHydrogenSites()
  reconstruction.resolveCollisions()
  reconstruction.createHydrogenBonds()
  topology = reconstruction.topology
  topology.sort()
  
  
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  forceField.minimize()
  for i in forceField.positions.indices {
    topology.atoms[i].position = forceField.positions[i]
  }
  
  // Next, create all the jigs you'll need for measuring the elastic moduli.
  return topology.atoms
}

struct SurfaceReconstruction {
  var material: MaterialType?
  var topology: Topology = Topology()
  var initialTypes: [MM4CenterType] = []
  
  func createBondLength() -> Float {
    var bondLength: Float
    switch material {
    case .elemental(let element):
      bondLength = 2 * element.covalentRadius
    case .checkerboard(let element, let element2):
      bondLength = element.covalentRadius + element2.covalentRadius
    case nil:
      fatalError("Material not specified.")
    }
    return bondLength
  }
  
  // These lists must always be sorted.
  var hydrogensToAtomsMap: [[UInt32]] = []
  var atomsToHydrogensMap: [[UInt32]] = []
  
  enum CollisionState {
    case keep
    case bond
    case oneHydrogen(Int)
  }
  
  // Remove malformed and primary carbons.
  mutating func removePathologicalAtoms() {
    var iteration = 0
    while true {
      let matches = topology.match(
        topology.atoms, algorithm: .absoluteRadius(createBondLength() * 1.1))
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
  
  // Form all center atom bonds in the lattice interior, assign center types.
  mutating func createBulkAtomBonds() {
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(createBondLength() * 1.1))
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
    
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    let bondLength = createBondLength()
    var hydrogenData: [SIMD4<Float>] = []
    
    for i in topology.atoms.indices {
      let atom = topology.atoms[i]
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
      hydrogenEntities, algorithm: .absoluteRadius(0.050))
    
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
  
  // Resolving three-way collisions requires something additional - a
  // specification of which hydrogen will survive.
  mutating func updateCollisions(_ states: [CollisionState]) {
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
  
  mutating func resolveCollisions() {
    var updates = [CollisionState?](
      repeating: nil, count: hydrogensToAtomsMap.count)
    
    func withTwoWayCollisions(_ closure: (UInt32, [UInt32]) -> Void) {
      for i in hydrogensToAtomsMap.indices {
        let atomList = hydrogensToAtomsMap[i]
        
        if atomList.count > 2 {
          fatalError("3-way collisions not handled yet.")
        }
        if atomList.count < 2 {
          continue
        }
        closure(UInt32(i), atomList)
      }
    }
    
    let orbitals = topology.nonbondingOrbitals()
    for i in orbitals.indices {
      let orbital = orbitals[i]
      if orbital.count == 2 {
        precondition(initialTypes[i] == .secondary)
      } else if orbital.count == 1 {
        precondition(initialTypes[i] == .tertiary)
      } else if orbital.count == 0 {
        precondition(initialTypes[i] == .quaternary)
      }
    }
    
    withTwoWayCollisions { i, atomList in
      var bridgeheadID: Int = -1
      var sidewallID: Int = -1
      var bothBridgehead = true
      var bothSidewall = true
      for atomID in atomList {
        switch initialTypes[Int(atomID)] {
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
      
      var linkedList: [Int] = []
      
      if bothBridgehead {
        fatalError("Edge case not handled yet.")
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
          
          let centerType = initialTypes[endOfList]
          precondition(centerType == .tertiary, "Must be a bridgehead carbon.")
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
          fatalError("3-way collisions not handled yet.")
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
}
