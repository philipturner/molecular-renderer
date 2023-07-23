//
//  Diamondoid.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import MolecularRenderer
import simd

struct Diamondoid {
  var atoms: [MRAtom]
  var bonds: [SIMD2<Int32>]
  
  // A bounding box that will never be exceeded during a simulation.
  var boundingBox: simd_float2x3
  
  init(carbonCenters: [SIMD3<Float>]) {
    let atoms = carbonCenters.map {
      MRAtom(origin: $0, element: 6)
    }
    self.init(atoms: atoms)
  }
  
  init(atoms: [MRAtom]) {
    let sp3BondAngle = Constants.sp3BondAngle
    precondition(atoms.count > 0, "Not enough atoms.")
    
    var minPosition: SIMD3<Float> = SIMD3(repeating: .infinity)
    var maxPosition: SIMD3<Float> = SIMD3(repeating: -.infinity)
    for atom in atoms {
      minPosition = min(atom.origin, minPosition)
      maxPosition = max(atom.origin, maxPosition)
    }
    do {
      let supportedElements: [UInt8] = [1, 6]
      var maxBondLength: Float = 0
      for element in supportedElements {
        let length = Constants.bondLengthMax(element: element)
        maxBondLength = max(maxBondLength, length)
      }
      self.boundingBox = simd_float2x3(
        minPosition - maxBondLength,
        maxPosition + maxBondLength)
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
    
    self.atoms = []
    self.bonds = []
    for i in atoms.indices {
      self.atoms.append(atoms[i])
      
      var neighborTypes: [Int] = []
      var neighborCenters: [SIMD3<Float>] = []
      for j in 0..<centerTypes[i] {
        let index = Int(centerNeighbors[i][j])
        neighborTypes.append(centerTypes[index])
        neighborCenters.append(atoms[index].origin)
        
        if i < index {
          bonds.append(SIMD2(
            Int32(truncatingIfNeeded: i),
            Int32(truncatingIfNeeded: index)))
        }
      }
      
      let valenceElectrons = Constants.valenceElectrons(
        element: atoms[i].element)
      if centerTypes[i] > valenceElectrons {
        fatalError("Too many bonds.")
      }
      
      var totalBonds = centerTypes[i]
      func addHydrogen(direction: SIMD3<Float>) {
        guard totalBonds < valenceElectrons else {
          return
        }
        totalBonds += 1
        
        let bondLength = Constants.bondLengths[[1, atoms[i].element]]!.average
        let hydrogenCenter = atoms[i].origin + bondLength * direction
        self.atoms.append(MRAtom(origin: hydrogenCenter, element: 1))
        self.bonds.append(SIMD2(
          Int32(truncatingIfNeeded: i),
          Int32(truncatingIfNeeded: bonds.count)))
      }
      
      switch centerTypes[i] {
      case 4:
        break
      case 3:
        let sideAB = neighborCenters[1] - neighborCenters[0]
        let sideAC = neighborCenters[2] - neighborCenters[0]
        var normal = normalize(cross(sideAB, sideAC))
        
        let deltaA = atoms[i].origin - neighborCenters[0]
        if dot(normal, deltaA) < 0 {
          normal = -normal
        }
        
        addHydrogen(direction: normal)
      case 2:
        let midPoint = (neighborCenters[1] + neighborCenters[0]) / 2
        guard distance(midPoint, atoms[i].origin) > 0.001 else {
          fatalError("sp3 carbons are too close to 180 degrees.")
        }
        
        let normal = normalize(atoms[i].origin - midPoint)
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
        
        let j = Int(centerNeighbors[i][0])
        var referenceIndex: Int?
        for k in 0..<neighborTypes[0] {
          let index = Int(centerNeighbors[j][k])
          if i != index {
            referenceIndex = index
            break
          }
        }
        guard let referenceIndex else {
          fatalError("Could not find valid neighbor index.")
        }
        let referenceCenter = atoms[referenceIndex].origin
        let normal = normalize(atoms[i].origin - atoms[j].origin)
        
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
