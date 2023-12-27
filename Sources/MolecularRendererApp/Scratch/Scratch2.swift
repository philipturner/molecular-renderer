//
//  Scratch2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/26/23.
//

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
  
  let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  
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
