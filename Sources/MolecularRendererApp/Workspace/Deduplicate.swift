//
//  Deduplicate.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/23/24.
//

import Foundation
import HDL
import MM4
import Numerics

// MARK: - Deduplicate

func deduplicate(topology: Topology) -> Topology {
  let matches = topology.match(
    topology.atoms, algorithm: .absoluteRadius(0.010))
  let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  var removedAtoms: Set<UInt32> = []
  var insertedBonds: Set<SIMD2<UInt32>> = []
  
  for i in topology.atoms.indices {
    let atomI = topology.atoms[i]
    guard matches[i].count > 1 else {
      continue
    }
    precondition(matches[i].count == 2, "Too many overlapping atoms.")
    
    var j: Int = -1
    for match in matches[i] where i != match {
      j = Int(match)
    }
    let atomJ = topology.atoms[j]
    precondition(atomI.atomicNumber == atomJ.atomicNumber)
    
    // Choose the carbon with the lowest index, or the H duplicate associated
    // with that carbon.
    let neighborsI = atomsToAtomsMap[i]
    let neighborsJ = atomsToAtomsMap[j]
    precondition(neighborsI.count == neighborsJ.count)
    if atomI.atomicNumber == 1 {
      precondition(neighborsI.count == 1)
      guard neighborsI.first! < neighborsJ.first! else {
        continue
      }
    } else {
      precondition(neighborsI.count == 4)
      guard i < j else {
        continue
      }
    }
    
    if atomI.atomicNumber == 1 {
      removedAtoms.insert(UInt32(j))
      continue
    }
    
    struct Orbital {
      var neighborID: UInt32
      var neighborElement: UInt8
      var delta: SIMD3<Float>
    }
    func createOrbitals(_ index: Int) -> [Orbital] {
      let neighbors = atomsToAtomsMap[index]
      let selfAtom = topology.atoms[index]
      var output: [Orbital] = []
      for neighborID in neighbors {
        let otherAtom = topology.atoms[Int(neighborID)]
        var delta = otherAtom.position - selfAtom.position
        delta /= (delta * delta).sum().squareRoot()
        output.append(Orbital(
          neighborID: neighborID,
          neighborElement: otherAtom.atomicNumber,
          delta: delta))
      }
      return output
    }
    let orbitalsI = createOrbitals(i)
    var orbitalsJ = createOrbitals(j)
    var orbitalJMatches: [Int] = []
    for orbitalJ in orbitalsJ {
      var maxScore: Float = -.greatestFiniteMagnitude
      var maxIndex: Int = -1
      for indexI in 0..<4 {
        let orbitalI = orbitalsI[indexI]
        let score = (orbitalI.delta * orbitalJ.delta).sum()
        if score > maxScore {
          maxScore = score
          maxIndex = indexI
        }
      }
      precondition(maxIndex >= 0)
      precondition(!orbitalJMatches.contains(maxIndex))
      orbitalJMatches.append(maxIndex)
    }
    let nullOrbital = Orbital(
      neighborID: 0, neighborElement: 0, delta: .zero)
    var newOrbitalsJ = Array(repeating: nullOrbital, count: 4)
    for indexJ in 0..<4 {
      let maxIndex = orbitalJMatches[indexJ]
      newOrbitalsJ[maxIndex] = orbitalsJ[indexJ]
    }
    orbitalsJ = newOrbitalsJ
    
    for (orbitalI, orbitalJ) in zip(orbitalsI, orbitalsJ) {
      switch (orbitalI.neighborElement, orbitalJ.neighborElement) {
      case (1, 1):
        // The overlapping hydrogens should already be removed.
        break
      case (6, 6), (6, 32), (32, 6), (32, 32):
        if orbitalI.neighborID < orbitalJ.neighborID {
          // The sigma bond to the other carbon was duplicated, and will be
          // automatically removed.
          break
        } else {
          fatalError("Edge case not handled.")
        }
      case (6, 1), (32, 1):
        // The overlapping hydrogen and carbon are not already removed by
        // other code.
        removedAtoms.insert(orbitalJ.neighborID)
      case (1, 6), (1, 32):
        // The hydrogen from the first atom must be superseded by the carbon
        // from the second atom. That carbon is not registered as overlapping
        // anything, because its position differs from the replaced hydrogen.
        precondition(!removedAtoms.contains(orbitalJ.neighborID))
        removedAtoms.insert(orbitalI.neighborID)
        insertedBonds.insert(SIMD2(UInt32(i), orbitalJ.neighborID))
      default:
        fatalError("Unrecognized bond.")
      }
    }
    removedAtoms.insert(UInt32(j))
  }
  
  var output = topology
  output.insert(bonds: Array(insertedBonds))
  output.remove(atoms: Array(removedAtoms))
  return output
}
