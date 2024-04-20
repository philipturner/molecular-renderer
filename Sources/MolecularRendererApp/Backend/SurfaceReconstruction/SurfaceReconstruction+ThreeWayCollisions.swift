//
//  SurfaceReconstruction+ThreeWayCollisions.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/20/24.
//

import HDL

extension SurfaceReconstruction {
  mutating func resolveThreeWayCollisions() {
    guard let material else {
      fatalError("Material not specified.")
    }
    
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    var insertedAtoms: [Entity] = []
    for hydrogenSiteID in hydrogensToAtomsMap.indices {
      var atomList = hydrogensToAtomsMap[hydrogenSiteID]
      guard atomList.count == 3 || atomList.count == 4 else {
        continue
      }
      atomList.sort()
      
      // Iterate over the first three atoms in the collision.
      var orbitalPermutationCount: SIMD3<Int> = .zero
      for laneID in 0..<3 {
        let atomID = atomList[laneID]
        let orbitalList = orbitals[Int(atomID)]
        orbitalPermutationCount[laneID] = orbitalList.count
      }
      
      var bulkBondLength = Constant(.square) { material }
      bulkBondLength *= Float(3).squareRoot() / 4
      var bestPermutationScore: Float = .greatestFiniteMagnitude
      var bestPermutationAverage: SIMD3<Float>?
      
      // Loop over all possible combinations of bond directions.
      for index1 in 0..<orbitalPermutationCount[0] {
        for index2 in 0..<orbitalPermutationCount[1] {
          for index3 in 0..<orbitalPermutationCount[2] {
            let atomID1 = atomList[0]
            let atomID2 = atomList[1]
            let atomID3 = atomList[2]
            let atom1 = topology.atoms[Int(atomID1)]
            let atom2 = topology.atoms[Int(atomID2)]
            let atom3 = topology.atoms[Int(atomID3)]
            let position1 = atom1.position
            let position2 = atom2.position
            let position3 = atom3.position
            
            let orbitals1 = orbitals[Int(atomID1)]
            let orbitals2 = orbitals[Int(atomID2)]
            let orbitals3 = orbitals[Int(atomID3)]
            let orbital1 = orbitals1[index1]
            let orbital2 = orbitals2[index2]
            let orbital3 = orbitals3[index3]
            let estimate1 = position1 + bulkBondLength * orbital1
            let estimate2 = position2 + bulkBondLength * orbital2
            let estimate3 = position3 + bulkBondLength * orbital3
            
            let delta12 = estimate1 - estimate2
            let delta13 = estimate1 - estimate3
            let delta23 = estimate2 - estimate3
            let distance12 = (delta12 * delta12).sum().squareRoot()
            let distance13 = (delta13 * delta13).sum().squareRoot()
            let distance23 = (delta23 * delta23).sum().squareRoot()
            
            let score = distance12 + distance13 + distance23
            let average = (estimate1 + estimate2 + estimate3) / 3
            if score < bestPermutationScore {
              bestPermutationScore = score
              bestPermutationAverage = average
            }
          }
        }
      }
      
      guard bestPermutationScore < 0.01 * bulkBondLength,
            let bestPermutationAverage else {
        fatalError("Could not find suitable orbital permutation.")
      }
      
      // Iterate over all 3-4 atoms in the collision.
      var atomicNumbersDict: [UInt8: Int] = [:]
      for atomID in atomList {
        let atom = topology.atoms[Int(atomID)]
        let atomicNumber = atom.atomicNumber
        if atomicNumbersDict[atomicNumber] == nil {
          atomicNumbersDict[atomicNumber] = 1
        } else {
          atomicNumbersDict[atomicNumber]! += 1
        }
      }
      
      // For checkerboard patterns, select the element that doesn't equal the
      // neighbor atoms.
      var maxAtomicNumber: UInt8 = .zero
      var maxAtomicNumberCount: Int = .zero
      for atomicNumber in atomicNumbersDict.keys {
        let count = atomicNumbersDict[atomicNumber]!
        if count > maxAtomicNumberCount {
          maxAtomicNumberCount = count
          maxAtomicNumber = atomicNumber
        }
      }
      
      // Fill in with atoms of the assigned material.
      var chosenAtomicNumber: UInt8
      switch material {
      case .elemental(let element):
        chosenAtomicNumber = element.rawValue
      case .checkerboard(let element1, let element2):
        if maxAtomicNumber == element1.rawValue {
          chosenAtomicNumber = element2.rawValue
        } else if maxAtomicNumber == element2.rawValue {
          chosenAtomicNumber = element1.rawValue
        } else {
          fatalError("Could not resolve identity of inserted atom in checkerboard structure.")
        }
      }
      
      let element = Element(rawValue: chosenAtomicNumber)!
      let entity = Entity(
        position: bestPermutationAverage, type: .atom(element))
      insertedAtoms.append(entity)
    }
    
    topology.insert(atoms: insertedAtoms)
  }
}
