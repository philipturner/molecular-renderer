//
//  Diamondoid.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import HDL
import MolecularRenderer
import RealModule
import QuaternionModule
#if os(macOS)
import QuartzCore
import simd
#endif

// MARK: - Duplicating Helper Functions for Speed

@inline(__always)
func _cross_platform_min<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> SIMD3<T> {
  return x.replacing(with: y, where: y .< x)
}

@inline(__always)
func _cross_platform_max<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> SIMD3<T> {
  return x.replacing(with: y, where: y .> x)
}

@inline(__always)
func _cross_platform_dot<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> T {
  return (x * y).sum()
}

@inline(__always)
func _cross_platform_length<T: Real & SIMDScalar>(
  _ x: SIMD3<T>
) -> T {
  return _cross_platform_dot(x, x).squareRoot()
}

@inline(__always)
func _cross_platform_distance<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> T {
  return _cross_platform_length(y - x)
}

@inline(__always)
func _cross_platform_floor<T: Real & SIMDScalar>(
  _ x: SIMD3<T>
) -> SIMD3<T> {
  return x.rounded(.down)
}

@inline(__always)
func _cross_platform_normalize<T: Real & SIMDScalar>(
  _ x: SIMD3<T>
) -> SIMD3<T> {
  return x / (_cross_platform_dot(x, x)).squareRoot()
}

@inline(__always)
func _cross_platform_cross<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> SIMD3<T> {
  // Source: https://en.wikipedia.org/wiki/Cross_product#Computing
  let s1 = x[1] * y[2] - x[2] * y[1]
  let s2 = x[2] * y[0] - x[0] * y[2]
  let s3 = x[0] * y[1] - x[1] * y[0]
  return SIMD3(s1, s2, s3)
}

// MARK: - Diamondoid

struct Diamondoid {
  var atoms: [MRAtom]
  var bonds: [SIMD2<Int32>]
  
  // These cannot be initialized until you finalize the position.
  //
  // The angular velocity must be w.r.t. the center of mass. Otherwise, you are
  // actually providing a linear velocity + a (different) angular velocity
  // around the center of mass.
  var linearVelocity: SIMD3<Float>?
  var angularVelocity: Quaternion<Float>?
  
  // An external force distributed across the entire object, in piconewtons.
  var externalForce: SIMD3<Float>?
  var atomsWithForce: [Bool] = []
  
  // You must ensure the number of anchors equals the number of atoms.
  // Otherwise, behavior is undefined.
  var anchors: [Bool] = []
  
  private var isVelocitySet: Bool {
    linearVelocity != nil ||
    angularVelocity != nil
  }
  
  init(atoms: [MRAtom], bonds: [SIMD2<Int32>]) {
    self.atoms = atoms
    self.bonds = bonds
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
      minPosition = _cross_platform_min(atom.origin, minPosition)
      maxPosition = _cross_platform_max(atom.origin, maxPosition)
    }
    
    // Build a uniform grid to search for neighbors in O(n) time.
    let cellSpaceMin = _cross_platform_floor(minPosition * Float(4))
    let cellSpaceMax = _cross_platform_floor(maxPosition * Float(4)) + 1
    let coordsOrigin = SIMD3<Int32>(cellSpaceMin)
    let boundingBox = SIMD3<Int32>(cellSpaceMax) &- coordsOrigin
    
    var grid = [SIMD2<Int32>](
      repeating: SIMD2(-1, 0),
      count: Int(boundingBox.x * boundingBox.y * boundingBox.z))
    var sectors: [SIMD16<Int32>] = []
    
    for (i, atom) in atoms.enumerated() {
      let cellSpaceFloor = _cross_platform_floor(atom.origin * Float(4))
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
      
      var searchBoxMin = SIMD3<Int32>(_cross_platform_floor((center - bondLengthMax) * 4))
      var searchBoxMax = SIMD3<Int32>(_cross_platform_floor((center + bondLengthMax) * 4))
      searchBoxMin &-= coordsOrigin
      searchBoxMax &-= coordsOrigin
      searchBoxMin = searchBoxMin.clamped(lowerBound: SIMD3<Int32>.zero, upperBound: boundingBox &- 1)
      searchBoxMax = searchBoxMax.clamped(lowerBound: SIMD3<Int32>.zero, upperBound: boundingBox &- 1)
      
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
          
          let deltaLength = _cross_platform_distance(
            atoms[i].origin, atoms[j].origin)
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
        createAtom(atoms: atoms, atomID: atomID)
      }
    }
    
    func createAtom(atoms: [MRAtom], atomID: Int) {
      precondition(atomID > -1)
      let thisAtom = atoms[atomID]
      
      let newAtomID = Int32(self.atoms.count)
      newIndicesMap[atomID] = newAtomID
      self.atoms.append(thisAtom)
      
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
        element: thisAtom.element)
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
          [1, thisAtom.element]]!.average
        let hydrogenCenter = thisAtom.origin + bondLength * direction
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
        var normal = _cross_platform_normalize(_cross_platform_cross(sideAB, sideAC))
        
        let deltaA = thisAtom.origin - neighborCenters[0]
        if _cross_platform_dot(normal, deltaA) < 0 {
          normal = -normal
        }
        
        addHydrogen(direction: normal)
      case 2:
        let midPoint = (neighborCenters[1] + neighborCenters[0]) / 2
        guard _cross_platform_distance(midPoint, thisAtom.origin) > 0.001 else {
          fatalError("sp3 carbons are too close to 180 degrees.")
        }
        
        let normal = _cross_platform_normalize(thisAtom.origin - midPoint)
        let axis = _cross_platform_normalize(neighborCenters[1] - midPoint)
        for angle in [-sp3BondAngle / 2, sp3BondAngle / 2] {
          let rotation = Quaternion<Float>(angle: angle, axis: axis)
          let direction = rotation.act(on: normal)
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
        let normal = _cross_platform_normalize(thisAtom.origin - atoms[j].origin)
        
        let referenceDelta = atoms[j].origin - referenceCenter
        var orthogonal = referenceDelta - normal * _cross_platform_dot(normal, referenceDelta)
        guard _cross_platform_length(orthogonal) > 0.001 else {
          fatalError("sp3 carbons are too close to 180 degrees.")
        }
        orthogonal = _cross_platform_normalize(orthogonal)
        let axis = _cross_platform_cross(normal, orthogonal)
        
        var directions: [SIMD3<Float>] = []
        let firstHydrogenRotation = Quaternion<Float>(
          angle: .pi - sp3BondAngle, axis: axis)
        directions.append(firstHydrogenRotation.act(on: normal))
        
        let secondHydrogenRotation = Quaternion<Float>(
          angle: 120 * .pi / 180, axis: normal)
        directions.append(secondHydrogenRotation.act(on: directions[0]))
        directions.append(secondHydrogenRotation.act(on: directions[1]))
        
        for direction in directions {
          addHydrogen(direction: direction)
        }
      default:
        fatalError("This should never happen.")
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
        guard cross_platform_distance(midPoint, thisAtom.origin) > 0.001 else {
          fatalError("sp3 carbons are too close to 180 degrees.")
        }
        
        let normal = _cross_platform_normalize(thisAtom.origin - midPoint)
        let axis = _cross_platform_normalize(cleanNeighbors[1].origin - midPoint)
        let sp3BondAngle = Constants.sp3BondAngle
        
        for angle in [-sp3BondAngle / 2, sp3BondAngle / 2] {
          let rotation = Quaternion<Float>(angle: angle, axis: axis)
          let direction = rotation.act(on: normal)
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
            return _cross_platform_distance(atomOrigin, self.atoms[hydrogenID].origin)
          }
          if candidateLengths[0] < candidateLengths[1] {
            dirtyDirections = [dirtyDirections[1]]
          } else {
            dirtyDirections = [dirtyDirections[0]]
          }
          let sum = _cross_platform_normalize(normal + dirtyDirections[0])
          var rotation = Quaternion<Float>(from: dirtyDirections[0], to: sum)
          dirtyDirections = [sum]
          
          rotation = Quaternion<Float>(
            angle: rotation.angle * 0.5, axis: rotation.axis)
          
          var previousHydrDelta = (
            self.atoms[hydrogenID].origin - thisAtom.origin)
          previousHydrDelta = rotation.act(on: previousHydrDelta)
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
        var normal = _cross_platform_normalize(_cross_platform_cross(sideAB, sideAC))
        
        let deltaA = thisAtom.origin - cleanNeighbors[0].origin
        if _cross_platform_dot(normal, deltaA) < 0 {
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
        var movedDistance = cross_platform_distance(newHydrogen, dirtyNeighbor)
        
        // Need to raise the tolerance from 0.04 to 0.08.
        if movedDistance < 0.08 {
          // Maybe perform a quaternion rotation that would make it correct.
          if dirtyNeighbors.count == 2 {
            print("WARNING: Did not move enough: \(movedDistance)")
          } else if movedDistance > 0.04 {
            let delta = newHydrogen - dirtyNeighbor
            newHydrogen += delta
            
            
            let movedDistance1 = movedDistance
            
            
            let dirtyDelta = _cross_platform_normalize(dirtyNeighbor - thisAtom.origin)
            let attemptDelta = _cross_platform_normalize(newHydrogen - thisAtom.origin)
            let attemptRot = Quaternion<Float>(from: dirtyDelta, to: attemptDelta)
            
            // distance on circumference = angle (in radians) * 1 radius
            // angle = distance on circumference / 1 radius
            precondition(attemptRot.angle >= 0)
            let attemptAxis = attemptRot.axis
            let newAngle = 0.08 / bondLength
            
            let newRot = Quaternion<Float>(angle: newAngle, axis: attemptAxis)
            let newDelta = _cross_platform_normalize(newRot.act(on: dirtyDelta))
            
            newHydrogen = thisAtom.origin + bondLength * newDelta
            movedDistance = cross_platform_distance(newHydrogen, dirtyNeighbor)
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
  
  // Remove groups that cause a lot of unnecessary degrees of freedom, or whose
  // vibrational frequencies are significantly changed by hydrogen mass
  // repartitioning:
  // - primary carbons
  // - pairs of 2 secondary carbons, which form a standalone ethyl chain
  // - except when the carbon is an anchor
  //
  // This should be done after fixing colliding hydrogens. In theory, this
  // function should never produce a new pair of colliding hydrogens.
  mutating func removeLooseCarbons(iterations: Int = 3) {
    if iterations == 0 {
      self._removeLooseCarbons(onlyMethyls: true)
      return
    }
    
    var copy = self
    var converged = false
    for iterationID in 0..<iterations {
      let removedAny = copy._removeLooseCarbons(onlyMethyls: false)
      if !removedAny {
        converged = true
        print("NOTE: Removing loose carbons converged on iteration \(iterationID).")
        break
      }
    }
    if converged {
      self = copy
    } else {
      print("NOTE: Removing loose carbons failed to converge after \(iterations) iterations.")
      self._removeLooseCarbons(onlyMethyls: true)
    }
  }
  
  // Remove the loose carbons several times, in an iterature procedure that
  // hopefully converges.
  // - Returns whether any atoms were modified during this iteration.
  @discardableResult
  private mutating func _removeLooseCarbons(onlyMethyls: Bool) -> Bool {
    var atomsToBondsMap: [Int: SIMD4<Int>] = [:]
    for bondID in bonds.indices {
      let bond = bonds[bondID]
      for lane in 0..<2 {
        let atomID = Int(bond[lane])
        var previous = atomsToBondsMap[atomID] ?? SIMD4(repeating: -1)
        var failed = true
        for lane in 0..<4 {
          guard previous[lane] == -1 else {
            continue
          }
          failed = false
          previous[lane] = bondID
          atomsToBondsMap[atomID] = previous
          break
        }
        if failed {
          fatalError("More than 4 bonds on an atom: \(previous).")
        }
      }
    }
    
    var shouldRemoveArray = [Bool](repeating: false, count: atoms.count)
    var shouldMakeHydrogenArray = [Bool](repeating: false, count: atoms.count)
    var carbonTypesArray = [Int](repeating: -1, count: atoms.count)
    
    // A new hydrogen neighbor index will sometimes be written, but not used. It
    // is only used when the current atom ends up transformed into a hydrogen.
    var newHydrogenNeighborIndices = [Int](repeating: -1, count: atoms.count)
    for trialID in 0..<3 {
      // Make two passes through the data. The first pass establishes which
      // carbon type each carbon is.
      for atomID in atoms.indices {
        let atom = self.atoms[atomID]
        if atom.element == 1 {
          continue
        }
        guard let map = atomsToBondsMap[atomID] else {
          fatalError("No map found for atom \(atomID).")
        }
        guard !any(map .== -1) else {
          fatalError("Found -1 in tetravalent atom map: \(map).")
        }
        
        // The closure accepts the hydrogen atom's ID.
        func forNeighbor(_ closure: (Int) -> Void) {
          for mapLane in 0..<4 {
            let bondID = map[mapLane]
            let bond = self.bonds[bondID]
            for bondLane in 0..<2 {
              let otherAtomID = Int(bond[bondLane])
              if otherAtomID == atomID {
                continue
              } else {
                closure(otherAtomID)
              }
            }
          }
        }
        
        var selfCarbonType: Int
        
        if trialID == 0 {
          var numHydrogenNeighbors = 0
          forNeighbor { neighborID in
            if atoms[neighborID].element == 1 {
              numHydrogenNeighbors += 1
            }
          }
          
          switch numHydrogenNeighbors {
          case 0: selfCarbonType = 4
          case 1: selfCarbonType = 3
          case 2: selfCarbonType = 2
          case 3: selfCarbonType = 1
          case 4: selfCarbonType = 0
          default: fatalError("This should never happen.")
          }
          carbonTypesArray[atomID] = selfCarbonType
        } else if trialID == 1 {
          selfCarbonType = carbonTypesArray[atomID]
          guard selfCarbonType >= 0 else {
            fatalError("Invalid carbon type.")
          }
          if anchors.count > 0, anchors[atomID] {
            // Skip anchor carbons.
            continue
          }
          
          var selfShouldMakeHydrogen = false
          var selfShouldRemove = false
          if selfCarbonType <= 1 {
            selfShouldMakeHydrogen = true
          } else if selfCarbonType == 2, !onlyMethyls {
            // Remove secondary carbons if 'onlyMethyls' is false.
            var numChangedNeighbors = 0
            forNeighbor { neighborID in
              let neighborType = carbonTypesArray[neighborID]
              if anchors.count > 0, anchors[neighborID] {
                // Skip anchor carbons.
                return
              }
              if neighborType >= 0, neighborType <= 2 {
                selfShouldMakeHydrogen = true
                numChangedNeighbors += 1
              }
            }
            if numChangedNeighbors == 2 {
              selfShouldMakeHydrogen = false
              selfShouldRemove = true
            }
          }
          if selfShouldMakeHydrogen {
            shouldMakeHydrogenArray[atomID] = true
          } else if selfShouldRemove {
            shouldRemoveArray[atomID] = true
          }
          if selfShouldMakeHydrogen || selfShouldRemove {
            forNeighbor { neighborID in
              if atoms[neighborID].element == 1 {
                shouldRemoveArray[neighborID] = true
              }
            }
          }
        } else if trialID == 2 {
          forNeighbor { neighborID in
            if atoms[neighborID].element == 1 {
              return
            }
            if !shouldRemoveArray[neighborID],
               !shouldMakeHydrogenArray[neighborID] {
              newHydrogenNeighborIndices[atomID] = neighborID
            }
          }
        }
      }
    }
    
    // Replace the "should make hydrogen" with silicon and replace the "should
    // remove" with fluorine, for visualization. If the remapping happens
    // successfully, all the Si/F atoms will be replaced with C/H/void.
    var modifiedAnAtom = false
    for atomID in atoms.indices {
      if shouldMakeHydrogenArray[atomID] {
        atoms[atomID].element = 14
        modifiedAnAtom = true
      } else if shouldRemoveArray[atomID] {
        atoms[atomID].element = 9
        modifiedAnAtom = true
      }
    }
    defer {
      for atom in atoms {
        guard atom.element == 1 || atom.element == 6 || atom.element == 14 else {
          fatalError("Did not remove all non-carbon atoms from the structure.")
        }
      }
    }
    
    var pointer = 0
    var newIndicesMap = [Int](repeating: -1, count: atoms.count)
    guard let chBondConstants = Constants.bondLengths[[1, 6]],
          let sihBondConstants = Constants.bondLengths[[1, 14]] else {
      fatalError("No C-H bond constants found.")
    }
    for atomID in atoms.indices {
      if shouldRemoveArray[atomID] {
        continue
      } else if shouldMakeHydrogenArray[atomID] {
        atoms[atomID].element = 1
        let neighborIndex = newHydrogenNeighborIndices[atomID]
        guard neighborIndex > -1 else {
          fatalError("No new-hydrogen neighbor index found.")
        }
        
        let neighborCenter = atoms[neighborIndex].origin
        var selfCenter = atoms[atomID].origin
        let delta = _cross_platform_normalize(selfCenter - neighborCenter)
        
        var average: Float
        if atoms[neighborIndex].element == 14 {
          average = sihBondConstants.average
        } else {
          average = chBondConstants.average
        }
        selfCenter = neighborCenter + delta * average
        atoms[atomID].origin = selfCenter
      }
      
      newIndicesMap[atomID] = pointer
      pointer += 1
    }
    
    var newBonds: [SIMD2<Int32>] = []
    for bondID in bonds.indices {
      let bond = self.bonds[bondID]
      var newBond: SIMD2<Int32> = .init(repeating: -1)
      var removeBond = false
      for bondLane in 0..<2 {
        let atomID = Int(bond[bondLane])
        if shouldRemoveArray[atomID] {
          // Remove this bond from the structure.
          removeBond = true
        } else {
          let newIndex = newIndicesMap[atomID]
          newBond[bondLane] = Int32(truncatingIfNeeded: newIndex)
        }
      }
      if atoms[Int(bond[0])].element == 1,
         atoms[Int(bond[1])].element == 1 {
        // Remove bonds between two hydrogens.
        removeBond = true
      }
      if !removeBond {
        if any(newBond .== -1) {
          fatalError("Invalid atom in new bond.")
        }
        newBonds.append(newBond)
      }
    }
    self.bonds = newBonds
    
    var newAtoms: [MRAtom] = []
    var newAnchors: [Bool] = []
    for atomID in atoms.indices {
      if newIndicesMap[atomID] == -1 {
        continue
      } else {
        newAtoms.append(atoms[atomID])
        if anchors.count > 0 {
          newAnchors.append(anchors[atomID])
        }
      }
    }
    self.atoms = newAtoms
    self.anchors = newAnchors
    return modifiedAnAtom
  }
  
  // Remove hydrogens that are too close. This is a last resort, where the inner
  // edges between (111) and (110) surfaces are like (100). It has O(n^2)
  // computational complexity.
  //
  // In the new RigidBody API, with the MM4 simulator supporting 5-membered
  // rings, it should be possible to:
  // - 1) Better automate the fixing of corner bonds.
  // - 2) Simulate these carbons more accurately.
  // - 3) Fix hydrogens with O(n) computational complexity.
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
    
    var bondsWithHydrogen: [Int] = []
    for i in 0..<bonds.count {
      guard let hydrogenID1 = getHydrogenID(bonds[i]) else {
        continue
      }
      let hydrogen1 = atoms[hydrogenID1]
      if let criterion {
        if !criterion(hydrogen1.origin) {
          continue
        }
      }
      bondsWithHydrogen.append(i)
    }
    
    var bondPairs: [SIMD2<Int>] = []
  outer:
    for (index_i, bond_i) in bondsWithHydrogen.enumerated() {
      let hydrogenID1 = getHydrogenID(bonds[bond_i])!
      let hydrogen1 = atoms[hydrogenID1]
      guard index_i + 1 < bondsWithHydrogen.count else {
        continue
      }
      
    inner:
      for index_j in (index_i + 1)..<bondsWithHydrogen.count {
        let bond_j = bondsWithHydrogen[index_j]
        let hydrogenID2 = getHydrogenID(bonds[bond_j])!
        
        if hydrogenID1 == hydrogenID2 {
          continue inner
        }
        let hydrogen2 = atoms[hydrogenID2]
        
        // For some reason, there's a 500x performance drop when the
        // cross_platform_distance function is used.
        if simd_distance(hydrogen1.origin, hydrogen2.origin) < tolerance {
          bondPairs.append(SIMD2(bond_i, bond_j))
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
  private static func makeBoundingBox(
    atoms: [MRAtom]
  ) -> (SIMD3<Float>, SIMD3<Float>) {
    var minPosition: SIMD3<Float> = SIMD3(repeating: .infinity)
    var maxPosition: SIMD3<Float> = SIMD3(repeating: -.infinity)
    for atom in atoms {
      minPosition = _cross_platform_min(atom.origin, minPosition)
      maxPosition = _cross_platform_max(atom.origin, maxPosition)
    }
    
    let supportedElements: [UInt8] = [1, 6]
    var maxBondLength: Float = 0
    for element in supportedElements {
      let length = Constants.bondLengthMax(element: element)
      maxBondLength = max(maxBondLength, length)
    }
    return (
      minPosition - maxBondLength,
      maxPosition + maxBondLength)
  }
  
  func createBoundingBox() -> (SIMD3<Float>, SIMD3<Float>) {
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
        velocity += _cross_platform_cross(w, r)
      }
      return velocity
    }
  }
  
  func createForces() -> [SIMD3<Float>] {
    var output = [SIMD3<Float>](repeating: .zero, count: atoms.count)
    if let externalForce {
      var atomsWithForce: [Bool]
      if self.atomsWithForce.count > 0 {
        guard self.atomsWithForce.count == atoms.count else {
          fatalError("'atomsWithForce' must be the same size as 'atoms'.")
        }
        atomsWithForce = self.atomsWithForce
      } else {
        atomsWithForce = [Bool](repeating: true, count: atoms.count)
      }
      
      // Only exert a force on the carbons. This will be changed to a better
      // heuristic with the new RigidBody API.
      let numCarbons = atoms.indices.reduce(Int(0)) {
        $0 + ((atoms[$1].element == 6 && atomsWithForce[$1]) ? 1 : 0)
      }
      let atomForce = externalForce / Float(numCarbons)
      output = atoms.indices.map {
        (atoms[$0].element == 6 && atomsWithForce[$0]) ? atomForce : .zero
      }
    }
    return output
  }
  
  mutating func translate(offset: SIMD3<Float>) {
    precondition(!isVelocitySet)
    for i in 0..<atoms.count {
      atoms[i].origin += offset
    }
  }
  
  // Rotations always occur around the center of mass for simplicity (you can
  // emulate off-axis rotations through a separate linear translation).
  mutating func rotate(angle: Quaternion<Float>) {
    precondition(!isVelocitySet)
    
    let centerOfMass = createCenterOfMass()
    let basis1 = angle.act(on: [1, 0, 0])
    let basis2 = angle.act(on: [0, 1, 0])
    let basis3 = angle.act(on: [0, 0, 1])
    for i in atoms.indices {
      var delta = atoms[i].origin - centerOfMass
      delta = delta.x*basis1 + delta.y*basis2 + delta.z*basis3
      atoms[i].origin = centerOfMass + delta
    }
  }
  
  // Remove '_Old_MM4' dependency so this file can be compiled in isolation.
  #if false
  mutating func minimize(temperature: Double = 298, fsPerFrame: Double = 100) {
    var diamondoid = self
    diamondoid.linearVelocity = nil
    diamondoid.angularVelocity = nil
    
    let simulator = _Old_MM4(
      diamondoid: diamondoid, fsPerFrame: fsPerFrame, temperature: temperature)
    let emptyVelocities: [SIMD3<Float>] = Array(
      repeating: .zero, count: diamondoid.atoms.count)
    
    let numIterations = 8
    for iteration in 0..<numIterations {
      if fsPerFrame > 1 {
        simulator.simulate(ps: 0.5, minimizing: true)
      } else {
        simulator.simulate(ps: 0.5, minimizing: true)
      }
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
  #endif
  
  // Center of mass using HMR.
  // WARNING: The amount of repartitioned mass must stay in sync with _Old_MM4.
  func createCenterOfMass() -> SIMD3<Float> {
    var masses = atoms.map { atom -> Float in
      switch atom.element {
      case 1:
        return 1.008
      case 6:
        return 12.011
      case 7:
        return 14.007
      case 14:
        return 28.085
      case 16:
        return 32.06
      case 32:
        return 72.6308
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
      case 7:
        return 14.007
      case 14:
        return 28.085
      case 16:
        return 32.06
      case 32:
        return 72.6308
      default:
        fatalError("Unsupported element: \(atom.element)")
      }
    }
    return masses.reduce(0, +)
  }
}

extension Diamondoid {
  init<T: Basis>(lattice: Lattice<T>) {
    self.init(atoms: lattice.atoms.map(MRAtom.init))
  }
  
  mutating func rotate(degrees: Float, axis: SIMD3<Float>) {
    let quaternion = Quaternion<Float>(angle: degrees * .pi / 180, axis: axis)
    self.rotate(angle: quaternion)
  }
  
  mutating func setCenterOfMass(_ center: SIMD3<Float>) {
    var translation = -createCenterOfMass()
    translation += center
    self.translate(offset: translation)
  }
  
  mutating func transform(_ closure: (inout MRAtom) -> Void) {
    for atomID in self.atoms.indices {
      closure(&self.atoms[atomID])
    }
  }
  
  init(topology: Topology) {
    let atoms = topology.atoms.map(MRAtom.init)
    let bonds = topology.bonds.map(SIMD2<Int32>.init(truncatingIfNeeded:))
    self.init(atoms: atoms, bonds: bonds)
  }
}

extension ArrayAtomProvider {
  init(_ diamondoids: [Diamondoid]) {
    var atoms: [MRAtom] = []
    for diamondoid in diamondoids {
      atoms += diamondoid.atoms
    }
    self.init(atoms)
  }
}

// MARK: - Old Bond Topology Backend

struct Constants {
  struct BondLength {
    var range: ClosedRange<Float>
    var average: Float
  }
  
  // CH and CC are shown extensively in literature. Other pairs of elements do
  // not have explicit reference values, so they are generated from the table
  // at:
  // https://periodictable.com/Properties/A/CovalentRadius.v.log.html
  //
  // These statistics are all for sigma bonds; pi bonds are not supported yet.
  static let bondLengths: [SIMD2<UInt8>: BondLength] = [
    [1, 6]: BondLength(range: 0.104...0.114, average: 0.109),
    [1, 7]: BondLength(range: 0.097...0.107, average: 0.102),
    [1, 8]: BondLength(range: 0.092...0.102, average: 0.097),
    [1, 14]: BondLength(range: 0.143...0.153, average: 0.148),
    [1, 16]: BondLength(range: 0.131...0.141, average: 0.136),
    [1, 32]: BondLength(range: 0.148...0.158, average: 0.153),
    
//    [6, 6]: BondLength(range: 0.149...0.159, average: 0.154),
    [6, 6]: BondLength(range: 0.148...0.168, average: 0.154),
    [6, 7]: BondLength(range: 0.142...0.152, average: 0.147),
    [6, 8]: BondLength(range: 0.138...0.148, average: 0.143),
    [6, 14]: BondLength(range: 0.183...0.193, average: 0.188),
    [6, 32]: BondLength(range: 0.188...0.198, average: 0.195),
    
    // Source: https://en.wikipedia.org/wiki/Organosulfur_chemistry
    [6, 16]: BondLength(range: 0.170...0.195, average: 0.183),
    
    [7, 7]: BondLength(range: 0.137...0.147, average: 0.142),
    [7, 8]: BondLength(range: 0.132...0.142, average: 0.137),
    
    // Source:
    // - https://open.library.ubc.ca/media/stream/pdf/24/1.0135560/1
    // - page 27
    [7, 16]: BondLength(range: 0.171...0.181, average: 0.176),
    
    [8, 8]: BondLength(range: 0.127...0.137, average: 0.132),
    [8, 16]: BondLength(range: 0.166...0.176, average: 0.171),
    
    [14, 14]: BondLength(range: 0.227...0.237, average: 0.232),
    [32, 32]: BondLength(range: 0.235...0.250, average: 0.240),
  ]
  
  static func bondLengthMax(element: UInt8) -> Float {
    var output: Float = 0
    for key in bondLengths.keys {
      guard key[0] == element || key[1] == element else {
        continue
      }
      let length = bondLengths[key]!.range.upperBound
      output = max(output, length)
    }
    guard output > 0 else {
      fatalError("No bond lengths found for element \(element).")
    }
    return output
  }
  
  static func valenceElectrons(element: UInt8) -> Int {
    switch element {
    case 1: return 1
    case 6: return 4
    case 7: return 3
    case 8: return 2
    case 14: return 4
    case 16: return 2
    case 32: return 4
    default: fatalError("Element \(element) not supported.")
    }
  }
  
  static let sp2BondAngle: Float = 120 * .pi / 180
  static let sp3BondAngle: Float = 109.5 * .pi / 180
}

func sp2Delta(
  start: SIMD3<Float>, axis: SIMD3<Float>
) -> SIMD3<Float> {
  
  let rotation = Quaternion<Float>(angle: Constants.sp2BondAngle / 2, axis: axis)
  return rotation.act(on: start)
}

func sp3Delta(
  start: SIMD3<Float>, axis: SIMD3<Float>
) -> SIMD3<Float> {
  
  let rotation = Quaternion<Float>(angle: Constants.sp3BondAngle / 2, axis: axis)
  return rotation.act(on: start)
}

/// Rounds an integer up to the nearest power of 2.
func roundUpToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - max(0, input - 1).leadingZeroBitCount)
}

/// Rounds an integer down to the nearest power of 2.
func roundDownToPowerOf2(_ input: Int) -> Int {
  1 << (Int.bitWidth - 1 - input.leadingZeroBitCount)
}
