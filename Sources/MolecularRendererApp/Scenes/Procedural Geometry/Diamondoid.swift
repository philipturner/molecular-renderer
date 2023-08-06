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
  
  // Remove this once you've redesigned the motion API.
  var velocities: [SIMD3<Float>]
  
  // These cannot be initialized until you finalize the position.
  //
  // The angular velocity must be w.r.t. the center of mass. Otherwise, you are
  // actually providing a linear velocity + a (different) angular velocity
  // around the center of mass.
  var linearVelocity: SIMD3<Float>?
  var angularVelocity: simd_quatf?
  
  private var isVelocitySet: Bool {
    linearVelocity != nil ||
    angularVelocity != nil
  }
  
  init(carbonCenters: [SIMD3<Float>]) {
    let atoms = carbonCenters.map {
      MRAtom(origin: $0, element: 6)
    }
    self.init(atoms: atoms)
  }
  
  init(atoms: [MRAtom], velocities: [SIMD3<Float>]? = nil) {
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
          if deltaLength <= bondLength.range.upperBound {
            neighbors.append(j)
          }
          if deltaLength < bondLength.range.lowerBound {
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
    self.velocities = []
    
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
        self.velocities.append(velocities?[atomID] ?? .zero)
        
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
          self.velocities.append(velocities?[atomID] ?? .zero)
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
  
  mutating func moveToOrigin(explosionFactor: Float) {
    precondition(!isVelocitySet)
    
    let centerOfMass = self.createCenterOfMass()
    for i in 0..<atoms.count {
      atoms[i].origin -= centerOfMass
      atoms[i].origin *= explosionFactor
    }
  }
  
  mutating func translate(offset: SIMD3<Float>) {
    precondition(!isVelocitySet)
    
    // Translate the atoms.
  }
  
  // Rotations always occur around the center of mass for simplicity (you can
  // emulate off-axis rotations through a separate linear translation).
  mutating func rotate(angle: simd_quatf) {
    precondition(!isVelocitySet)
    
    // modify the atom positions
  }
  
  // Center of mass using HMR.
  // WARNING: The amount of repartitioned mass must stay in sync with MM4.
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
    for i in atoms.indices {
      centerOfMass += masses[i] * atoms[i].origin
    }
    centerOfMass /= Float(atoms.count)
    return centerOfMass
  }
}
