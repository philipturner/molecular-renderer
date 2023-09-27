//
//  Diamondoid.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import MolecularRenderer
import simd
import QuartzCore

struct Diamondoid {
  var atoms: [MRAtom]
  var bonds: [SIMD2<Int32>]
  
  // These cannot be initialized until you finalize the position.
  //
  // The angular velocity must be w.r.t. the center of mass. Otherwise, you are
  // actually providing a linear velocity + a (different) angular velocity
  // around the center of mass.
  var linearVelocity: SIMD3<Float>?
  var angularVelocity: simd_quatf?
  
  // TODO: Partition into finite elements when there's elastic deformation. Each
  // chunk will have its linear and angular momentum conserved, and the
  // thermostat applied locally. Rescale the temperature of each chunk in the
  // system to conserve energy, but randomize the velocity changes within each
  // chunk.
  //
  // Better: do this partitioning automatically, in addition to a constraint
  // placed on the entire rigid body. Test this on the diamondoid collision
  // simulation.
  
  private var isVelocitySet: Bool {
    linearVelocity != nil ||
    angularVelocity != nil
  }
  
  init(carbonCenters: [SIMD3<Float>], ccBondRange: ClosedRange<Float>? = nil) {
    let atoms = carbonCenters.map {
      MRAtom(origin: $0, element: 6)
    }
    self.init(atoms: atoms, ccBondRange: ccBondRange)
  }
  
  init(atoms: [MRAtom], ccBondRange: ClosedRange<Float>? = nil) {
    let sp3BondAngle = Constants.sp3BondAngle
    precondition(atoms.count > 0, "Not enough atoms.")
    
    var minPosition: SIMD3<Float> = SIMD3(repeating: .infinity)
    var maxPosition: SIMD3<Float> = SIMD3(repeating: -.infinity)
    for atom in atoms {
      minPosition = min(atom.origin, minPosition)
      maxPosition = max(atom.origin, maxPosition)
    }
    
    // Build a uniform grid to search for neighbors in O(n) time.
    let cellSpaceMin = floor(minPosition * 4)
    let cellSpaceMax = floor(maxPosition * 4) + 1
    let coordsOrigin = SIMD3<Int32>(cellSpaceMin)
    let boundingBox = SIMD3<Int32>(cellSpaceMax) &- coordsOrigin
    
    var grid = [SIMD2<Int32>](
      repeating: SIMD2(-1, 0),
      count: Int(boundingBox.x * boundingBox.y * boundingBox.z))
    var sectors: [SIMD16<Int32>] = []
    
    for (i, atom) in atoms.enumerated() {
      let cellSpaceFloor = floor(atom.origin * 4)
      let coords = SIMD3<Int32>(cellSpaceFloor) &- coordsOrigin
      var address = coords.x
      address += boundingBox.x * coords.y
      address += boundingBox.x * boundingBox.y * coords.z
      
      var previous = grid[Int(address)]
      precondition(previous[1] < 16, "Too many atoms in a sector.")
      
      if previous[0] == -1 {
        previous[0] = Int32(sectors.count)
        sectors.append(SIMD16(repeating: -1))
      }
      sectors[Int(previous[0])][Int(previous[1])] = Int32(i)
      
      previous[1] += 1
      grid[Int(address)] = previous
    }
    
    // Primary (1), secondary (2), tertiary (3), or quaternary (4).
    var centerTypes: [Int] = []
    var centerNeighbors: [SIMD4<Int32>] = []
    
    for i in atoms.indices {
      let atom = atoms[i]
      let center = atom.origin
      let bondLengthMax = Constants.bondLengthMax(element: atom.element)
      
      var searchBoxMin = SIMD3<Int32>(floor((center - bondLengthMax) * 4))
      var searchBoxMax = SIMD3<Int32>(floor((center + bondLengthMax) * 4))
      searchBoxMin &-= coordsOrigin
      searchBoxMax &-= coordsOrigin
      searchBoxMin = clamp(searchBoxMin, min: .zero, max: boundingBox &- 1)
      searchBoxMax = clamp(searchBoxMax, min: .zero, max: boundingBox &- 1)
      
      var addresses: [Int32] = []
      for z in searchBoxMin.z...searchBoxMax.z {
        let planeAddress = boundingBox.x * boundingBox.y * z
        for y in searchBoxMin.y...searchBoxMax.y {
          for x in searchBoxMin.x...searchBoxMax.x {
            addresses.append(planeAddress + boundingBox.x * y + x)
          }
        }
      }
      
      let ccBondMinMax = ccBondRange ?? Constants
        .bondLengths[[6, 6]]!.range
      var neighbors: [Int] = []
      for address in addresses {
        let sector = grid[Int(address)]
        guard sector[1] > 0 else {
          continue
        }
        
        let indices = sectors[Int(sector[0])]
        for k in 0..<Int(sector[1]) {
          let j = Int(indices[k])
          guard i != j else {
            continue
          }
          
          let deltaLength = distance(atoms[i].origin, atoms[j].origin)
          let firstIndex: UInt8 = atoms[i].element
          let secondIndex: UInt8 = atoms[j].element
          let key = SIMD2(
            min(firstIndex, secondIndex),
            max(firstIndex, secondIndex))
          
          let bondLength = Constants.bondLengths[key]!
          let bondRange = all(key .== 6)
          ? ccBondMinMax : bondLength.range
          if deltaLength <= bondRange.upperBound {
            neighbors.append(j)
          }
          if deltaLength < bondRange.lowerBound {
            fatalError("Bond length too short: \(deltaLength)")
          }
        }
      }
      precondition(neighbors.count > 0, "No neighbors found.")
      precondition(neighbors.count <= 4, "More than four neighbors.")
      centerTypes.append(neighbors.count)
      
      var output: SIMD4<Int32> = .init(repeating: -1)
      for k in neighbors.indices {
        output[k] = Int32(truncatingIfNeeded: neighbors[k])
      }
      centerNeighbors.append(output)
    }
    
    // Round up the grid size to a binary multiple in each dimension, then
    // create a cube with that size. Most cells will be skipped, especially for
    // elongated structures, but that's not a bottleneck right now. It can be
    // easily fixed in a future optimization that polishes up the code.
    var newIndicesMap: [Int32] = Array(repeating: -1, count: atoms.count)
    self.atoms = []
    self.bonds = []
    
    let dimensionRangeEnds = SIMD3<Int>(
      roundUpToPowerOf2(Int(boundingBox[0]) + 1),
      roundUpToPowerOf2(Int(boundingBox[1]) + 1),
      roundUpToPowerOf2(Int(boundingBox[2]) + 1))
    let maxDimension = dimensionRangeEnds.max()
    let mortonRangeEnd = 1 << (3 * maxDimension.trailingZeroBitCount)
    
    let initialMasks: SIMD3<Int> = SIMD3(1, 2, 4)
    var dimensionIncludedMasks: SIMD3<Int> = .zero
    var dimensionCandidateMasks: SIMD3<Int> = .zero
    for dim in 0..<3 {
      let trailingZeroes = dimensionRangeEnds[dim].trailingZeroBitCount
      for i in 0..<trailingZeroes {
        dimensionIncludedMasks[dim] |= initialMasks[dim] << (3 * i)
      }
      dimensionCandidateMasks[dim] = dimensionIncludedMasks[dim]
      for i in trailingZeroes...maxDimension.trailingZeroBitCount {
        dimensionCandidateMasks[dim] |= initialMasks[dim] << (3 * i)
      }
    }
    precondition(all(dimensionIncludedMasks .<= mortonRangeEnd))
    precondition(any(dimensionIncludedMasks .>= mortonRangeEnd >> 3))
    precondition(all(dimensionCandidateMasks .>= mortonRangeEnd))
    
  outer:
    for mortonIndex in 0..<mortonRangeEnd {
      for dim in 0..<3 {
        let candidateMask = mortonIndex & dimensionCandidateMasks[dim]
        let includedMask = mortonIndex & dimensionIncludedMasks[dim]
        if candidateMask != includedMask {
          continue outer
        }
      }
      
      // Source:
      // https://stackoverflow.com/a/28358035
      /*
       uint64_t morton3(uint64_t x) {
           x = x & 0x9249249249249249;
           x = (x | (x >> 2))  & 0x30c30c30c30c30c3;
           x = (x | (x >> 4))  & 0xf00f00f00f00f00f;
           x = (x | (x >> 8))  & 0x00ff0000ff0000ff;
           x = (x | (x >> 16)) & 0xffff00000000ffff;
           x = (x | (x >> 32)) & 0x00000000ffffffff;
           return x;
       }
       uint64_t bits;
       uint64_t x = morton3(bits)
       uint64_t y = morton3(bits>>1)
       uint64_t z = morton3(bits>>2)
       */
      
      func morton3(_ input: Int) -> Int {
        var x = UInt64(input) & 0x9249249249249249
        x = (x | (x >> 2))  & 0x30c30c30c30c30c3
        x = (x | (x >> 4))  & 0xf00f00f00f00f00f
        x = (x | (x >> 8))  & 0x00ff0000ff0000ff
        x = (x | (x >> 16)) & 0xffff00000000ffff
        x = (x | (x >> 32)) & 0x00000000ffffffff
        return Int(x)
      }
      let x = Int32(morton3(mortonIndex))
      let y = Int32(morton3(mortonIndex >> 1))
      let z = Int32(morton3(mortonIndex >> 2))
      let coords = SIMD3(x, y, z)
      if any(coords .>= boundingBox) {
        continue outer
      }
      
      var address = coords.x
      address += boundingBox.x * coords.y
      address += boundingBox.x * boundingBox.y * coords.z
      let gridSlot = grid[Int(address)]
      
      let numAtoms = Int(gridSlot[1])
      precondition(numAtoms <= 16)
      guard numAtoms > 0 else {
        continue
      }
      
      let sector = sectors[Int(gridSlot[0])]
      for slotIndex in 0..<numAtoms {
        let atomID = Int(sector[slotIndex])
        precondition(atomID > -1)
        
        let newAtomID = Int32(self.atoms.count)
        newIndicesMap[atomID] = newAtomID
        self.atoms.append(atoms[atomID])
        
        var neighborTypes: [Int] = []
        var neighborCenters: [SIMD3<Float>] = []
        for j in 0..<centerTypes[atomID] {
          let index = Int(centerNeighbors[atomID][j])
          neighborTypes.append(centerTypes[index])
          neighborCenters.append(atoms[index].origin)
          
          // Change this; store the bonds with indices being sorted inside the
          // bond, but only add a bond when the neighbor is already inside the
          // final list.
          let newNeighborID = newIndicesMap[index]
          guard newNeighborID > -1 else {
            continue
          }
          var newBond: SIMD2<Int32> = .zero
          newBond[0] = min(newAtomID, newNeighborID)
          newBond[1] = max(newAtomID, newNeighborID)
          bonds.append(newBond)
        }
        
        let valenceElectrons = Constants.valenceElectrons(
          element: atoms[atomID].element)
        if centerTypes[atomID] > valenceElectrons {
          fatalError("Too many bonds.")
        }
        
        var totalBonds = centerTypes[atomID]
        func addHydrogen(direction: SIMD3<Float>) {
          guard totalBonds < valenceElectrons else {
            return
          }
          totalBonds += 1
          
          let bondLength = Constants.bondLengths[
            [1, atoms[atomID].element]]!.average
          let hydrogenCenter = atoms[atomID].origin + bondLength * direction
          let hydrogenID = Int32(self.atoms.count)
          
          self.atoms.append(MRAtom(origin: hydrogenCenter, element: 1))
          self.bonds.append(SIMD2(Int32(newAtomID), hydrogenID))
        }
        
        switch centerTypes[atomID] {
        case 4:
          break
        case 3:
          let sideAB = neighborCenters[1] - neighborCenters[0]
          let sideAC = neighborCenters[2] - neighborCenters[0]
          var normal = normalize(cross(sideAB, sideAC))
          
          let deltaA = atoms[atomID].origin - neighborCenters[0]
          if dot(normal, deltaA) < 0 {
            normal = -normal
          }
          
          addHydrogen(direction: normal)
        case 2:
          let midPoint = (neighborCenters[1] + neighborCenters[0]) / 2
          guard distance(midPoint, atoms[atomID].origin) > 0.001 else {
            fatalError("sp3 carbons are too close to 180 degrees.")
          }
          
          let normal = normalize(atoms[atomID].origin - midPoint)
          let axis = normalize(neighborCenters[1] - midPoint)
          for angle in [-sp3BondAngle / 2, sp3BondAngle / 2] {
            let rotation = simd_quatf(angle: angle, axis: axis)
            let direction = simd_act(rotation, normal)
            addHydrogen(direction: direction)
          }
        case 1:
          guard neighborTypes[0] > 1 else {
            fatalError("Cannot determine structure of primary carbon.")
          }
          
          let j = Int(centerNeighbors[atomID][0])
          var referenceIndex: Int?
          for k in 0..<neighborTypes[0] {
            let index = Int(centerNeighbors[j][k])
            if atomID != index {
              referenceIndex = index
              break
            }
          }
          guard let referenceIndex else {
            fatalError("Could not find valid neighbor index.")
          }
          let referenceCenter = atoms[referenceIndex].origin
          let normal = normalize(atoms[atomID].origin - atoms[j].origin)
          
          let referenceDelta = atoms[j].origin - referenceCenter
          var orthogonal = referenceDelta - normal * dot(normal, referenceDelta)
          guard length(orthogonal) > 0.001 else {
            fatalError("sp3 carbons are too close to 180 degrees.")
          }
          orthogonal = normalize(orthogonal)
          let axis = cross(normal, orthogonal)
          
          var directions: [SIMD3<Float>] = []
          let firstHydrogenRotation = simd_quatf(
            angle: .pi - sp3BondAngle, axis: axis)
          directions.append(simd_act(firstHydrogenRotation, normal))
          
          let secondHydrogenRotation = simd_quatf(
            angle: 120 * .pi / 180, axis: normal)
          directions.append(simd_act(secondHydrogenRotation, directions[0]))
          directions.append(simd_act(secondHydrogenRotation, directions[1]))
          
          for direction in directions {
            addHydrogen(direction: direction)
          }
        default:
          fatalError("This should never happen.")
        }
      }
    }
  }
  
  func findAtoms(where criterion: (MRAtom) -> Bool) -> [Int] {
    var output: [Int] = []
    for i in atoms.indices {
      if criterion(atoms[i]) {
        output.append(i)
      }
    }
    return output
  }
  
  mutating func removeAtoms(atIndices indices: [Int]) {
    var newAtoms: [MRAtom?] = atoms
    for index in indices {
      newAtoms[index] = nil
    }
    var newBonds: [SIMD2<Int32>?] = bonds.map { $0 }
    
    var dirtyAtomBrokenBonds: [Int] = .init(repeating: 0, count: atoms.count)
    var dirtyAtomOriginalIndices: [[Int]?] = .init(
      repeating: nil, count: atoms.count)
    var atomsToBondsMap: [Int: [Int]] = [:]
    for (i, bond) in bonds.enumerated() {
      for j in 0..<2 {
        let atomID = Int(bond[j])
        var previous = atomsToBondsMap[atomID] ?? []
        previous.append(i)
        atomsToBondsMap[atomID] = previous
      }
    }
    
  outer:
    for bondID in newBonds.indices {
      let bond = newBonds[bondID]!
      var occupiedAtom: MRAtom
      var occupiedIndex: Int
      var removedIndex: Int
      
      switch (newAtoms[Int(bond.x)], newAtoms[Int(bond.y)]) {
      case (nil, nil):
        newBonds[bondID] = nil
        continue outer
      case (.some(_), .some(_)):
        continue outer
      case (.some(let atom), nil):
        occupiedAtom = atom
        occupiedIndex = Int(bond[0])
        removedIndex = Int(bond[1])
      case (nil, .some(let atom)):
        occupiedAtom = atom
        removedIndex = Int(bond[0])
        occupiedIndex = Int(bond[1])
      }
      
      if occupiedAtom.element == 1 {
        // Remove dangling hydrogens.
        newAtoms[occupiedIndex] = nil
        fatalError("Occupied atom element was hydrogen.")
      } else if occupiedAtom.element == 6 {
        dirtyAtomBrokenBonds[occupiedIndex] += 1
        if dirtyAtomOriginalIndices[occupiedIndex] == nil {
          dirtyAtomOriginalIndices[occupiedIndex] = [removedIndex]
        } else {
          dirtyAtomOriginalIndices[occupiedIndex]!.append(removedIndex)
        }
      } else {
        fatalError("Unexpected element: \(occupiedAtom.element)")
      }
    }
    
    var atomsNewLocations: [Int] = []
    var currentNewIndex: Int = 0
    for (atom, brokenBondCount) in zip(newAtoms, dirtyAtomBrokenBonds) {
      if atom == nil {
        atomsNewLocations.append(-1)
      } else {
        atomsNewLocations.append(currentNewIndex)
        currentNewIndex += 1
        guard brokenBondCount >= 1 else {
          continue
        }
        
        for _ in 0..<brokenBondCount {
          currentNewIndex += 1
        }
      }
    }
    
    var copyAtoms = newAtoms
    newAtoms = []
    var appendedBonds: [SIMD2<Int32>] = []
    for (oldAtomID, brokenBondCount) in dirtyAtomBrokenBonds.enumerated() {
      guard copyAtoms[oldAtomID] != nil else {
        continue
      }
      newAtoms.append(copyAtoms[oldAtomID])
      guard brokenBondCount > 0 else {
        continue
      }
      
      let originalIndices = dirtyAtomOriginalIndices[oldAtomID]
      guard let originalIndices else {
        fatalError("Original indices were nil.")
      }
      if originalIndices.count > 2 {
        fatalError("Case not handled yet.")
      }
      
      let cleanBonds = atomsToBondsMap[oldAtomID]!
      var dirtyNeighbors: [MRAtom] = []
      var cleanNeighbors: [MRAtom] = []
      var cleanIDs: [Int] = []
      
    inner:
      for cleanBondID in cleanBonds.indices {
        let bond = bonds[cleanBonds[cleanBondID]]
        if atomsNewLocations[Int(bond[0])] == -1 {
          dirtyNeighbors.append(self.atoms[Int(bond[0])])
          continue inner
        } else if atomsNewLocations[Int(bond[1])] == -1 {
          dirtyNeighbors.append(self.atoms[Int(bond[1])])
          continue inner
        }
        
        var cleanAtom: MRAtom
        if Int(bond[0]) == oldAtomID {
          cleanAtom = self.atoms[Int(bond[1])]
          cleanIDs.append(Int(bond[1]))
        } else if Int(bond[1]) == oldAtomID {
          cleanAtom = self.atoms[Int(bond[0])]
          cleanIDs.append(Int(bond[0]))
        } else {
          fatalError("This should never happen (a).")
        }
        cleanNeighbors.append(cleanAtom)
      }
      precondition(dirtyNeighbors.count == originalIndices.count)
      let thisAtom = self.atoms[oldAtomID]
      
      var dirtyDirections: [SIMD3<Float>] = []
      
      let hasHydrogen = cleanNeighbors.contains(where: { $0.element == 1 })
      if hasHydrogen {
        precondition(cleanNeighbors.filter { $0.element == 1 }.count == 1)
      }
      if cleanNeighbors.count == 2 || hasHydrogen {
        var hydrogenID: Int?
        if hasHydrogen {
          let index = cleanNeighbors.firstIndex(where: { $0.element == 1 })!
          hydrogenID = cleanIDs[index]
          cleanNeighbors = cleanNeighbors.filter { $0.element != 1 }
        }
        
        let midPoint = (
          cleanNeighbors[1].origin + cleanNeighbors[0].origin) / 2
        guard distance(midPoint, thisAtom.origin) > 0.001 else {
          fatalError("sp3 carbons are too close to 180 degrees.")
        }
        
        let normal = normalize(thisAtom.origin - midPoint)
        let axis = normalize(cleanNeighbors[1].origin - midPoint)
        let sp3BondAngle = Constants.sp3BondAngle
        
        for angle in [-sp3BondAngle / 2, sp3BondAngle / 2] {
          let rotation = simd_quatf(angle: angle, axis: axis)
          let direction = simd_act(rotation, normal)
          dirtyDirections.append(direction)
        }
        
        if hasHydrogen {
          let bondLength = Constants.bondLengths[
            [1, thisAtom.element]]!.average
          guard let hydrogenID else {
            fatalError("Hydrogen neighbor was nil.")
          }
          let candidateLengths = dirtyDirections.map { direction in
            let atomOrigin = thisAtom.origin + bondLength * direction
            return distance(atomOrigin, self.atoms[hydrogenID].origin)
          }
          if candidateLengths[0] < candidateLengths[1] {
            dirtyDirections = [dirtyDirections[1]]
          } else {
            dirtyDirections = [dirtyDirections[0]]
          }
          let sum = normalize(normal + dirtyDirections[0])
          var rotation = simd_quatf(from: dirtyDirections[0], to: sum)
          dirtyDirections = [sum]
          
          rotation = simd_quatf(
            angle: rotation.angle * 0.5, axis: rotation.axis)
          
          var previousHydrDelta = (
            self.atoms[hydrogenID].origin - thisAtom.origin)
          previousHydrDelta = simd_act(rotation, previousHydrDelta)
          let newHydrOrigin = thisAtom.origin + previousHydrDelta
          
          let mappedHydrogenID = atomsNewLocations[hydrogenID]
          guard mappedHydrogenID > -1 else {
            fatalError("Mapped hydrogen ID did not exist.")
          }
          if mappedHydrogenID < newAtoms.count {
            newAtoms[mappedHydrogenID]!.origin = newHydrOrigin
          } else {
            copyAtoms[hydrogenID]!.origin = newHydrOrigin
          }
        }
      } else if cleanNeighbors.count == 3 {
        let sideAB = cleanNeighbors[1].origin - cleanNeighbors[0].origin
        let sideAC = cleanNeighbors[2].origin - cleanNeighbors[0].origin
        var normal = normalize(cross(sideAB, sideAC))
        
        let deltaA = thisAtom.origin - cleanNeighbors[0].origin
        if dot(normal, deltaA) < 0 {
          normal = -normal
        }
        if dirtyNeighbors.count >= 2 {
          fatalError("This should never happen.")
        }
        dirtyDirections.append(normal)
      } else {
        fatalError("This should never happen.")
      }
      
      
      let newBondFirstID = Int32(newAtoms.count - 1)
      
      for dirtyID in dirtyDirections.indices {
        let bondLength = Constants.bondLengths[
          [1, thisAtom.element]]!.average
        
        let direction = dirtyDirections[dirtyID]
        var newHydrogen = thisAtom.origin + bondLength * direction
        let dirtyNeighbor = dirtyNeighbors[dirtyID].origin
        var movedDistance = distance(newHydrogen, dirtyNeighbor)
        
        // Need to raise the tolerance from 0.04 to 0.08.
        if movedDistance < 0.08 {
          // Maybe perform a quaternion rotation that would make it correct.
          if dirtyNeighbors.count == 2 {
            print("WARNING: Did not move enough: \(movedDistance)")
          } else if movedDistance > 0.04 {
            let delta = newHydrogen - dirtyNeighbor
            newHydrogen += delta
            
            
            let movedDistance1 = movedDistance
            
            
            let dirtyDelta = normalize(dirtyNeighbor - thisAtom.origin)
            let attemptDelta = normalize(newHydrogen - thisAtom.origin)
            let attemptRot = simd_quatf(from: dirtyDelta, to: attemptDelta)
            
            // distance on circumference = angle (in radians) * 1 radius
            // angle = distance on circumference / 1 radius
            precondition(attemptRot.angle >= 0)
            let attemptAxis = attemptRot.axis
            let newAngle = 0.08 / bondLength
            
            let newRot = simd_quatf(angle: newAngle, axis: attemptAxis)
            let newDelta = normalize(simd_act(newRot, dirtyDelta))
            
            newHydrogen = thisAtom.origin + bondLength * newDelta
            movedDistance = distance(newHydrogen, dirtyNeighbor)
            if movedDistance < 0.08 {
              print("Did not move enough (1): \(movedDistance1)")
              print("Did not move enough (2): \(movedDistance)")
              fatalError("Did not move enough (2): \(movedDistance)")
            }
          } else {
            fatalError("Did not move enough: \(movedDistance)")
          }
        }
        
        // Insert new hydrogens right next to the atoms that bond to them,
        // ensuring the atoms stay sorted in Morton order.
        let element: UInt8 = (dirtyNeighbors.count == 2) ? 0 : 1
        let newAtom = MRAtom(origin: newHydrogen, element: element)
        newAtoms.append(newAtom)
        
        let newBondSecondID = Int32(newAtoms.count - 1)
        precondition(newBondFirstID > -1)
        precondition(newBondSecondID > -1)
        appendedBonds.append(SIMD2(newBondFirstID, newBondSecondID))
      }
    }
    
    for i in newBonds.indices {
      guard var bond = newBonds[i] else {
        continue
      }
      bond[0] = Int32(atomsNewLocations[Int(bond[0])])
      bond[1] = Int32(atomsNewLocations[Int(bond[1])])
      if bond[0] == -1 && bond[1] == -1 {
        fatalError("Bond with ID \(i) had two references to -1.")
      } else if bond[0] == -1 || bond[1] == -1 {
        newBonds[i] = nil
        continue
      }
      newBonds[i] = bond
    }
    
    precondition(!newAtoms.contains(nil))
    self.atoms = newAtoms.compactMap { $0 }
    self.bonds = newBonds.compactMap { $0 } + appendedBonds
    
    // Validate integrity of the new topology.
    do {
      var atomsToBondsMap: [Int: [Int]] = [:]
      for (bondID, bond) in bonds.enumerated() {
        let id1 = Int(bond[0])
        let id2 = Int(bond[1])
        for id in [id1, id2] {
          // Ensure the reference points to something valid.
          if id == -1 {
            fatalError("Bond contained reference to -1.")
          }
          if id >= atoms.count {
            fatalError("Out of bounds reference: \(id).")
          }
          let atom = self.atoms[id]
          precondition(
            atom.element == 1 || atom.element == 6, "Corrupted atom.")
          
          if let map = atomsToBondsMap[id] {
            atomsToBondsMap[id] = map + [bondID]
          } else {
            atomsToBondsMap[id] = [bondID]
          }
        }
      }
      
      for (atomID, atom) in self.atoms.enumerated() {
        let thisBonds = atomsToBondsMap[atomID]
        guard let thisBonds else {
          fatalError("No bonds connected to this atom.")
        }
        if atom.element == 1 {
          guard thisBonds.count == 1 else {
            fatalError("Hydrogen had bond count \(thisBonds.count).")
          }
          let bond = self.bonds[thisBonds[0]]
          guard Int(bond[0]) == atomID ||
                  Int(bond[1]) == atomID else {
            fatalError("Hydrogen had corrupted bond indices.")
          }
        } else if atom.element == 6 {
          guard thisBonds.count == 4 else {
            fatalError("Carbon had bond count \(thisBonds.count).")
          }
          for thisBond in thisBonds {
            let bond = self.bonds[thisBond]
            guard Int(bond[0]) == atomID ||
                  Int(bond[1]) == atomID else {
              fatalError("Carbon had corrupted bond indices.")
            }
          }
        }
      }
    }
  }
  
  // Remove hydrogens that are too close. This is a last resort, where the inner
  // edges between (111) and (110) surfaces are like (100). It has O(n^2)
  // computational complexity.
  //
  // TODO: Change this to O(n) so it's feasible in Swift debug mode. In fact,
  // run it during the creation of 'Diamondoid' as an argument disabled by
  // default.
  mutating func fixHydrogens(
    tolerance: Float,
    where criterion: ((SIMD3<Float>) -> Bool)? = nil
  ) {
    func getHydrogenID(_ bond: SIMD2<Int32>) -> Int? {
      let atom1 = atoms[Int(bond[0])]
      let atom2 = atoms[Int(bond[1])]
      if atom1.element == 1 {
        return Int(bond[0])
      } else if atom2.element == 1 {
        return Int(bond[1])
      } else {
        return nil
      }
    }
    
    func getCarbonID(_ bond: SIMD2<Int32>) -> Int? {
      let atom1 = atoms[Int(bond[0])]
      let atom2 = atoms[Int(bond[1])]
      if atom1.element == 1 {
        return Int(bond[1])
      } else if atom2.element == 1 {
        return Int(bond[0])
      } else {
        return nil
      }
    }
    
    var bondPairs: [SIMD2<Int>] = []
  outer:
    for i in 0..<bonds.count {
      guard let hydrogenID1 = getHydrogenID(bonds[i]) else {
        continue outer
      }
      let hydrogen1 = atoms[hydrogenID1]
      if let criterion {
        if !criterion(hydrogen1.origin) {
          continue outer
        }
      }
    inner:
      for j in (i + 1)..<bonds.count {
        guard let hydrogenID2 = getHydrogenID(bonds[j]) else {
          continue inner
        }
        
        if hydrogenID1 == hydrogenID2 {
          continue inner
        }
        
        let hydrogen2 = atoms[hydrogenID2]
        if let criterion {
          if !criterion(hydrogen2.origin) {
            continue inner
          }
        }
        if distance(hydrogen1.origin, hydrogen2.origin) < tolerance {
          bondPairs.append(SIMD2(i, j))
          continue outer
        }
      }
    }
    
    var newAtoms: [MRAtom?] = atoms.map { $0 }
    var newBonds: [SIMD2<Int32>?] = bonds.map { $0 }
  outer:
    for pair in bondPairs {
      var carbonIDs = SIMD2<Int32>(repeating: -1)
      for i in 0..<2 {
        // If one of these returns null, the bond was (incorrectly) referenced
        // multiple times.
        guard let hydrogenID = getHydrogenID(bonds[pair[i]]) else {
          fatalError()
//          continue outer
        }
        guard let carbonID = getCarbonID(bonds[pair[i]]) else {
          fatalError()
//          continue outer
        }
        newAtoms[hydrogenID] = nil
        carbonIDs[i] = Int32(carbonID)
      }
      newBonds[pair[0]] = carbonIDs
      newBonds[pair[1]] = nil
    }
    
    var atomsNewLocations: [Int] = []
    var currentNewIndex: Int = 0
    for atom in newAtoms {
      if atom == nil {
        atomsNewLocations.append(-1)
      } else {
        atomsNewLocations.append(currentNewIndex)
        currentNewIndex += 1
      }
    }
    for i in newBonds.indices {
      guard var bond = newBonds[i] else {
        continue
      }
      bond[0] = Int32(atomsNewLocations[Int(bond[0])])
      bond[1] = Int32(atomsNewLocations[Int(bond[1])])
      newBonds[i] = bond
    }
    
    self.atoms = newAtoms.compactMap { $0 }
    self.bonds = newBonds.compactMap { $0 }
  }
  
  // A bounding box that will never be exceeded during a simulation.
  private static func makeBoundingBox(atoms: [MRAtom]) -> simd_float2x3 {
    var minPosition: SIMD3<Float> = SIMD3(repeating: .infinity)
    var maxPosition: SIMD3<Float> = SIMD3(repeating: -.infinity)
    for atom in atoms {
      minPosition = min(atom.origin, minPosition)
      maxPosition = max(atom.origin, maxPosition)
    }
    
    let supportedElements: [UInt8] = [1, 6]
    var maxBondLength: Float = 0
    for element in supportedElements {
      let length = Constants.bondLengthMax(element: element)
      maxBondLength = max(maxBondLength, length)
    }
    return simd_float2x3(
      minPosition - maxBondLength,
      maxPosition + maxBondLength)
  }
  
  func createBoundingBox() -> simd_float2x3 {
    return Self.makeBoundingBox(atoms: atoms)
  }
  
  func createVelocities() -> [SIMD3<Float>] {
    var w: SIMD3<Float>?
    var centerOfMass: SIMD3<Float>?
    if let angularVelocity {
      let angleRadians = angularVelocity.angle
      let axis = angularVelocity.axis
      w = axis * angleRadians
      centerOfMass = createCenterOfMass()
    }
    
    return atoms.map { atom in
      var velocity = self.linearVelocity ?? .zero
      if let w, let centerOfMass {
        let r = atom.origin - centerOfMass
        velocity += cross(w, r)
      }
      return velocity
    }
  }
  
  mutating func translate(offset: SIMD3<Float>) {
    precondition(!isVelocitySet)
    for i in 0..<atoms.count {
      atoms[i].origin += offset
    }
  }
  
  // Rotations always occur around the center of mass for simplicity (you can
  // emulate off-axis rotations through a separate linear translation).
  mutating func rotate(angle: simd_quatf) {
    precondition(!isVelocitySet)
    
    let centerOfMass = createCenterOfMass()
    for i in atoms.indices {
      var delta = atoms[i].origin - centerOfMass
      delta = simd_act(angle, delta)
      atoms[i].origin = centerOfMass + delta
    }
  }
  
  mutating func minimize() {
    var diamondoid = self
    diamondoid.linearVelocity = nil
    diamondoid.angularVelocity = nil
    
    let simulator = _Old_MM4(
      diamondoid: diamondoid, fsPerFrame: 100)
    let emptyVelocities: [SIMD3<Float>] = Array(
      repeating: .zero, count: diamondoid.atoms.count)
    
    let numIterations = 8
    for iteration in 0..<numIterations {
      simulator.simulate(ps: 0.5, minimizing: true)
      if iteration < numIterations - 1 {
        simulator.provider.reset()
        simulator.thermalize(velocities: emptyVelocities)
      }
    }
    
    let minimized = simulator.provider.states.last!
    for j in diamondoid.atoms.indices {
      let remapped = Int(simulator.newIndicesMap[j])
      diamondoid.atoms[j].origin = minimized[remapped].origin
    }
    self = diamondoid
  }
  
  // Center of mass using HMR.
  // WARNING: The amount of repartitioned mass must stay in sync with _Old_MM4.
  func createCenterOfMass() -> SIMD3<Float> {
    var masses = atoms.map { atom -> Float in
      switch atom.element {
      case 1:
        return 1.008
      case 6:
        return 12.011
      default:
        fatalError("Unsupported element: \(atom.element)")
      }
    }
    
    for var bond in bonds {
      let firstAtom = atoms[Int(bond[0])]
      let secondAtom = atoms[Int(bond[1])]
      if min(firstAtom.element, secondAtom.element) != 1 {
        continue
      }
      if secondAtom.element == 1 {
        bond = SIMD2(bond[1], bond[0])
      }
      
      let hydrogenMass = masses[Int(bond[0])]
      var nonHydrogenMass = masses[Int(bond[1])]
      nonHydrogenMass -= (2.0 - hydrogenMass)
      masses[Int(bond[0])] = 2.0
      masses[Int(bond[1])] = nonHydrogenMass
    }
    
    var centerOfMass: SIMD3<Float> = .zero
    var totalMass: Float = .zero
    for i in atoms.indices {
      centerOfMass += masses[i] * atoms[i].origin
      totalMass += masses[i]
    }
    centerOfMass /= totalMass
    return centerOfMass
  }
  
  // Returns masses in atomic mass units (amu).
  func createMass() -> Float {
    let masses = atoms.map { atom -> Float in
      switch atom.element {
      case 1:
        return 1.008
      case 6:
        return 12.011
      default:
        fatalError("Unsupported element: \(atom.element)")
      }
    }
    return masses.reduce(0, +)
  }
}
