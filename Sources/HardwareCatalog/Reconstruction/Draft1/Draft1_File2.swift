// ALL OF THE IDEAS PRESENTED HERE ARE MIT LICENSED BY PHILIP A. TURNER (2024)
// THEY SHALL NEVER BE PATENTED IN ANY COUNTRY
// THE INVENTOR RESERVES THE RIGHT TO REVOKE A PARTY'S PERMISSION TO USE THESE
// IDEAS, AT HIS DISCRETION, IN RESPONSE TO EGREGIOUS CASES OF MISUSE

import Foundation
import HDL
import MolecularRenderer
import Numerics

// MARK: - Geometry Generation

func latticeDiamondoid() -> Diamondoid {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 6 * (h + k + l) }
    Material { .elemental(.carbon) }
  }
  var atoms = lattice.atoms.map(MRAtom.init).map(Optional.init)
  
outer:
  for i in atoms.indices {
    let selfAtom = atoms[i]!
    for j in atoms.indices where i != j {
      if let otherAtom = atoms[j] {
        let delta = selfAtom.origin - otherAtom.origin
        let distance = (delta * delta).sum().squareRoot()
        if distance < 0.154 * 1.2 {
          continue outer
        }
      }
    }
    atoms[i] = nil
  }
  
  return Diamondoid(atoms: atoms.compactMap { $0 })
}

func latticeBasic100() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 6 * (h + k + l) }
    Material { .elemental(.carbon) }
  }
  return lattice.atoms
}

// Find a good example of geometry that typically requires lonsdaleite,
// and includes (110)/(111) planes.
func latticeAdvanced100() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 6 * (h + k + l) }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 2 * (h + k + l) }
        
        var directionPairs: [(SIMD3<Float>, SIMD3<Float>)] = []
        directionPairs.append((-h, -k))
        directionPairs.append((-h, -l))
        directionPairs.append((-k, -l))
        for pair in directionPairs {
          Concave {
            Plane { pair.0 }
            Plane { pair.1 }
          }
        }
      }
      
      Convex {
        Origin { 5 * (h + k + l) }
        Plane { k + l }
        
        Origin { -3 * h }
        Origin { 1.5 * (h - k + l) }
        Valley(h + k + l) { k }
      }
      
      Convex {
        Origin { 5 * k + 3 * l }
        Valley(k + l) { k }
      }
      
      Concave {
        Convex {
          Origin { 5 * k + 2.5 * l }
          Valley(k + l) { k }
        }
        Convex {
          Origin { 3 * h }
          Plane { -h  }
        }
      }
      
      Concave {
        Convex {
          Origin { 5 * h + 1 * k + 5 * l }
          Plane { h - k + l }
        }
        Convex {
          Origin { 5 * h + 5 * l }
          Origin { -0.25 * (h + l) }
          Plane { h + l }
        }
        Convex {
          Origin { 5 * l }
          Plane { l }
        }
      }
      
      Replace { .empty }
    }
  }
  return lattice.atoms
}

func latticeSpherical100() -> [Entity] {
  let unitCell = Lattice<Cubic> { h, k, l in
    Bounds { 1 * (h + k + l) }
    Material { .elemental(.carbon) }
  }
  
  var output: [Entity] = []
  let latticeConstant = Constant(.square) { .elemental(.carbon) }
  for z in 0..<10 {
    for y in 0..<10  {
      for x in 0..<10 {
        let coordsInt = SIMD3<Int>(x, y, z)
        let coordsFloat = SIMD3<Float>(coordsInt)
        let center = coordsFloat - 5 + 0.5
        if (center * center).sum().squareRoot() < 5 {
          var cell = unitCell.atoms
          for i in cell.indices {
            cell[i].position += coordsFloat * latticeConstant
          }
          output += cell
        }
      }
    }
  }
  
  var topology = Topology()
  topology.insert(atoms: output)
  let duplicates = topology.match(
    topology.atoms, algorithm: .absoluteRadius(0.1))
  
  var removedAtoms: [UInt32] = []
  for i in topology.atoms.indices {
    let range = duplicates[i]
    for j in range {
      if i > j {
        removedAtoms.append(UInt32(i))
      }
    }
  }
  topology.remove(atoms: removedAtoms)
  
  return topology.atoms
}

func labelCarbonTypes(_ input: Topology) -> Topology {
  var topology = input
  let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  
  for i in topology.atoms.indices {
    let neighborIDs = atomsToAtomsMap[i]
    let neighborCount = neighborIDs.count
    
    if topology.atoms[i].atomicNumber == 6 {
      if neighborCount == 0 {
        topology.atoms[i].atomicNumber = 10
      } else if neighborCount == 1 {
        topology.atoms[i].atomicNumber = 9
      } else if neighborCount == 2 {
        topology.atoms[i].atomicNumber = 8
      } else if neighborCount == 3 {
        topology.atoms[i].atomicNumber = 7
      }
    }
  }
  return topology
}

// MARK: - Components of (100) Reconstruction

func cleanupLooseCarbons(
  _ topology: inout Topology,
  minimumNeighborCount: Int
) {
  var atomsToRemove: [UInt32] = []
  let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  for i in topology.atoms.indices {
    guard topology.atoms[i].atomicNumber == 6 else {
      continue
    }
    let neighborCount = atomsToAtomsMap[i].count
    if neighborCount < minimumNeighborCount {
      atomsToRemove.append(UInt32(i))
    }
  }
  topology.remove(atoms: atomsToRemove)
}

// Clean up all the places where 4 hydrogens collide.
func cleanupFourHydrogenCollisions(_ topology: inout Topology) {
  let chBondLength =
  Element.carbon.covalentRadius + Element.hydrogen.covalentRadius
  
  let matches = topology.match(
    topology.atoms, algorithm: .absoluteRadius(0.080))
  let farMatches = topology.match(
    topology.atoms, algorithm: .absoluteRadius(chBondLength * 1.01))
  var fourHydrogenSites: [SIMD4<UInt32>: Bool] = [:]
  
  for i in topology.atoms.indices {
    let range = matches[i]
    guard topology.atoms[i].atomicNumber == 1 else {
      continue
    }
    if range.count == 4 {
      var list: [UInt32] = []
      list.append(UInt32(i))
      for j in range[(range.startIndex+1)...] {
        list.append(j)
      }
      list.sort()
      
      var key: SIMD4<UInt32> = .zero
      for lane in 0..<4 {
        key[lane] = list[lane]
      }
      fourHydrogenSites[key] = true
    }
  }
  
  // Replace the four-hydrogen sites with a carbon.
  var hydrogensToRemove: [UInt32] = []
  for site in fourHydrogenSites.keys {
    var hydrogenAveragePosition: SIMD3<Float> = .zero
    var nearbyCarbonIDs: [UInt32] = []
    for lane in 0..<4 {
      let hydrogenID = Int(site[lane])
      let matchRange = matches[hydrogenID]
      let farMatchRange = farMatches[hydrogenID]
      precondition(matchRange.count == 4)
      precondition(farMatchRange.count == 5)
      
      let carbonID = Int(farMatchRange[farMatchRange.endIndex - 1])
      precondition(topology.atoms[carbonID].atomicNumber == 6)
      
      hydrogenAveragePosition += topology.atoms[hydrogenID].position
      nearbyCarbonIDs.append(UInt32(carbonID))
      hydrogensToRemove.append(site[lane])
    }
    hydrogenAveragePosition /= 4
    
    let newCarbon = Entity(
      position: hydrogenAveragePosition, type: .atom(.carbon))
    topology.insert(atoms: [newCarbon])
    
    let newCarbonID = UInt32(topology.atoms.count - 1)
    var newBonds: [SIMD2<UInt32>] = []
    for nearbyCarbonID in nearbyCarbonIDs {
      newBonds.append(SIMD2(nearbyCarbonID, newCarbonID))
    }
    topology.insert(bonds: newBonds)
  }
  topology.remove(atoms: hydrogensToRemove)
}

// Clean up all the places where 3 hydrogens collide.
// - If there's a bridgehead carbon, bond the two sidewalls.
// - If all 3 are sidewalls, the use cases seen so far suggest there's a pair
//   of nearby tri-hydrogen collisions. One can define a simple and consistent
//   rule that reconstructs the bonds without adding new carbons.
func cleanupThreeHydrogenCollisions(_ topology: inout Topology) {
  let chBondLength =
  Element.carbon.covalentRadius + Element.hydrogen.covalentRadius
  
  let matches = topology.match(
    topology.atoms, algorithm: .absoluteRadius(0.080))
  let farMatches = topology.match(
    topology.atoms, algorithm: .absoluteRadius(chBondLength * 1.01))
  var threeHydrogenSites: [SIMD3<UInt32>: Bool] = [:]
  
  for i in topology.atoms.indices {
    let range = matches[i]
    guard topology.atoms[i].atomicNumber == 1 else {
      continue
    }
    if range.count == 3 {
      var list: [UInt32] = []
      list.append(UInt32(i))
      for j in range[(range.startIndex+1)...] {
        list.append(j)
      }
      list.sort()
      
      var key: SIMD3<UInt32> = .zero
      for lane in 0..<3 {
        key[lane] = list[lane]
      }
      threeHydrogenSites[key] = true
    }
  }
  
  let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  var carbonTypesMap = [Int](repeating: -2, count: topology.atoms.count)
  for i in topology.atoms.indices {
    if topology.atoms[i].atomicNumber == 1 {
      // we haven't connected hydrogens yet
      precondition(atomsToAtomsMap[i].count == 0)
      carbonTypesMap[i] = -1 // hydrogen type
    } else {
      carbonTypesMap[i] = atomsToAtomsMap[i].count
    }
  }
  precondition(carbonTypesMap.allSatisfy { $0 != -2 })
  
  // Replace the three-hydrogen sites with 1 hydrogen and a bond.
  var hydrogensToRemove: [UInt32] = []
  
  for site in threeHydrogenSites.keys {
    var hydrogenData: [SIMD3<UInt32>] = []
    for lane in 0..<3 {
      let hydrogenID = Int(site[lane])
      let matchRange = matches[hydrogenID]
      let farMatchRange = farMatches[hydrogenID]
      precondition(matchRange.count == 3)
      precondition(farMatchRange.count == 4)
      
      let carbonID = Int(farMatchRange[farMatchRange.endIndex - 1])
      precondition(topology.atoms[carbonID].atomicNumber == 6)
      
      let carbonType = carbonTypesMap[carbonID]
      hydrogenData.append(
        SIMD3(UInt32(hydrogenID), UInt32(carbonID), UInt32(carbonType)))
    }
    hydrogenData.sort(by: { $0.z < $1.z })
    precondition(hydrogenData[0].z == 2)
    precondition(hydrogenData[1].z == 2)
    
    if hydrogenData[1].z == 3 {
      fatalError("This should never happen")
    } else if hydrogenData[2].z == 3 {
      let newBond = SIMD2<UInt32>(hydrogenData[0].y,
                                  hydrogenData[1].y)
      topology.insert(bonds: [newBond])
      hydrogensToRemove.append(hydrogenData[0].x)
      hydrogensToRemove.append(hydrogenData[1].x)
    } else if hydrogenData[2].z == 2 {
      var candidateCarbonIDs: [UInt32] = []
      for i in 0..<3 {
        let hydrogenID = hydrogenData[i].x
        let carbonID = hydrogenData[i].y
        
        var hydrogenNeighborCount = 0
        var otherHydrogenID: UInt32 = 0
        for farMatch in farMatches[Int(carbonID)] {
          let atom = topology.atoms[Int(farMatch)]
          guard atom.atomicNumber == 1 else {
            continue
          }
          hydrogenNeighborCount += 1
          if farMatch == hydrogenID {
            continue
          }
          otherHydrogenID = farMatch
        }
        precondition(hydrogenNeighborCount == 2)
        
        let otherHydrogenMatches = matches[Int(otherHydrogenID)]
        if otherHydrogenMatches.count == 3 {
          candidateCarbonIDs.append(carbonID)
        }
      }
      precondition(
        candidateCarbonIDs.count == 1, "Edge case failed to reconstruct.")
      
      var newBond: SIMD2<UInt32> = .zero
      var lane = 0
      for i in 0..<3 {
        let carbonID = hydrogenData[i].y
        guard carbonID != candidateCarbonIDs[0] else {
          continue
        }
        
        hydrogensToRemove.append(hydrogenData[i].x)
        newBond[lane] = carbonID
        lane += 1
      }
      topology.insert(bonds: [newBond])
    } else {
      fatalError("This should never happen.")
    }
  }
  topology.remove(atoms: hydrogensToRemove)
}

// Nudge carbons with very long bonds slightly toward each other.
// - Only nudges carbons that were just recently reconstructed.
// - Already nudged carbons are ignored.
func nudgeReconstructedCarbons(_ topology: inout Topology) {
  var nudges = [SIMD3<Float>](
    repeating: .zero, count: topology.atoms.count)
  let ccBondLength = 2 * Element.carbon.covalentRadius
  
  for bond in topology.bonds {
    let atom1 = topology.atoms[Int(bond.x)]
    let atom2 = topology.atoms[Int(bond.y)]
    guard atom1.atomicNumber == 6, atom2.atomicNumber == 6 else {
      continue
    }
    
    let delta1to2 = atom2.position - atom1.position
    let bondLength = (delta1to2 * delta1to2).sum().squareRoot()
    if bondLength < ccBondLength * 1.55 {
      continue
    }
    
    let bondShortening = 0.50 * (bondLength - ccBondLength)
    var nudge1to2 = delta1to2
    nudge1to2 /= bondLength
    nudge1to2 *= bondShortening / 2
    let nudge2to1 = -nudge1to2
    nudges[Int(bond.x)] += nudge1to2
    nudges[Int(bond.y)] += nudge2to1
  }
  
  for i in topology.atoms.indices {
    topology.atoms[i].position += nudges[i]
  }
}

// Create new hydrogens from existing carbon geometry.
// - Remove all hydrogens.
// - Regenerate new hydrogens based on existing orbitals.
func regenerateHydrogens(_ topology: inout Topology) {
  var hydrogenIDs: [UInt32] = []
  for i in topology.atoms.indices {
    let atom = topology.atoms[i]
    if atom.atomicNumber == 1 {
      hydrogenIDs.append(UInt32(i))
    }
  }
  topology.remove(atoms: hydrogenIDs)
  
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
}

// Clean up the final hydrogens for presentation.
// - Remove new hydrogens that have a collision.
// - Bond hydrogens to carbons.
// - Adjust bonded hydrogens that are way too close to a carbon.
func createHydrogenBonds(_ topology: inout Topology) {
  let chBondLength =
  Element.carbon.covalentRadius + Element.hydrogen.covalentRadius
  let matches = topology.match(
    topology.atoms, algorithm: .absoluteRadius(chBondLength * 1.01))
  let farMatches = topology.match(
    topology.atoms, algorithm: .absoluteRadius(0.160))
  
  var hydrogensToRemove: [UInt32] = []
  var nudges = [SIMD3<Float>](repeating: .zero, count: topology.atoms.count)
  
  for i in topology.atoms.indices {
    let range = matches[i]
    guard topology.atoms[i].atomicNumber == 1 else {
      continue
    }
    
    if range.count == 1 {
      fatalError("This should never happen.")
    } else if range.count == 2 {
      let bond = SIMD2(UInt32(i), range[range.endIndex - 1])
      topology.insert(bonds: [bond])
      
      let farRange = farMatches[i]
      if farRange.count > 2 {
        let selfAtom = topology.atoms[i]
        for j in farRange[(farRange.startIndex+2)...] {
          let otherAtom = topology.atoms[Int(j)]
          let delta = otherAtom.position - selfAtom.position
          let distance = (delta * delta).sum().squareRoot()
          
          // Numbers are acquired from MM4 parameters.
          // Units: angstrom -> nm
          var equilibriumVdwDistance: Float
          var forceMagnitude: Float
          switch otherAtom.atomicNumber {
          case 1:
            equilibriumVdwDistance = 2 * 1.640 / 10
            forceMagnitude = 0.15
          case 6:
            equilibriumVdwDistance = 3.440 / 10
            forceMagnitude = 0.20
          default:
            fatalError(
              "Element \(otherAtom.atomicNumber) not supported by (100) reconstruction yet.")
          }
          
          let force = equilibriumVdwDistance - distance
          
          var nudge = -delta / distance
          nudge *= forceMagnitude * force
          nudges[Int(i)] += nudge
        }
        
        let bondedCarbonID = farRange[farRange.startIndex+1]
        let bondedCarbon = topology.atoms[Int(bondedCarbonID)]
        precondition(
          bondedCarbon.atomicNumber == 6,
          "Second-closest match was not carbon.")
        
        var delta = selfAtom.position - bondedCarbon.position
        delta += nudges[Int(i)]
        let deltaLength = (delta * delta).sum().squareRoot()
        let force = chBondLength - deltaLength
        nudges[Int(i)] += delta / deltaLength * force
      }
    } else {
      hydrogensToRemove.append(UInt32(i))
    }
  }
  
  for i in topology.atoms.indices {
    topology.atoms[i].position += nudges[i]
  }
  topology.remove(atoms: hydrogensToRemove)
}
