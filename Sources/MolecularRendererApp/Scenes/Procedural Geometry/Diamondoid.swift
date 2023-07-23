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
  
  // TODO: Support N and O by accepting 'MRAtom' structures instead of position
  // vectors. When searching for neighbors, you'll need to adjust the accepted
  // distance based on the length of bonds between the two elements being
  // compared.
  init(carbonCenters: [SIMD3<Float>]) {
    precondition(carbonCenters.count > 0, "Not enough carbons.")
    
    var minPosition: SIMD3<Float> = SIMD3(repeating: .infinity)
    var maxPosition: SIMD3<Float> = SIMD3(repeating: -.infinity)
    for center in carbonCenters {
      minPosition = min(center, minPosition)
      maxPosition = max(center, maxPosition)
    }
    self.boundingBox = simd_float2x3(
      minPosition - ccBondLengthMax,
      maxPosition + ccBondLengthMax)
    
    // Build a uniform grid to search for neighbors in O(n) time.
    let cellSpaceMin = floor(minPosition * 4)
    let cellSpaceMax = floor(maxPosition * 4) + 1
    let coordsOrigin = SIMD3<Int32>(cellSpaceMin)
    let boundingBox = SIMD3<Int32>(cellSpaceMax) &- coordsOrigin
    
    var grid = [SIMD2<Int32>](
      repeating: SIMD2(-1, 0),
      count: Int(boundingBox.x * boundingBox.y * boundingBox.z))
    var sectors: [SIMD16<Int32>] = []
    
    for (i, center) in carbonCenters.enumerated() {
      let cellSpaceFloor = floor(center * 4)
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
    var carbonTypes: [Int] = []
    var carbonNeighbors: [SIMD4<Int32>] = []
    
    for i in carbonCenters.indices {
      let center = carbonCenters[i]
      var searchBoxMin = SIMD3<Int32>(floor((center - ccBondLengthMax) * 4))
      var searchBoxMax = SIMD3<Int32>(floor((center + ccBondLengthMax) * 4))
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
          
          let delta = carbonCenters[i] - carbonCenters[j]
          if length(delta) <= ccBondLengthMax {
            neighbors.append(j)
          }
        }
      }
      precondition(neighbors.count > 0, "No neighbors found.")
      precondition(neighbors.count <= 4, "More than four neighbors.")
      carbonTypes.append(neighbors.count)
      
      var output: SIMD4<Int32> = .init(repeating: -1)
      for k in neighbors.indices {
        output[k] = Int32(truncatingIfNeeded: neighbors[k])
      }
      carbonNeighbors.append(output)
    }
    
    atoms = []
    bonds = []
    for i in carbonCenters.indices {
      atoms.append(MRAtom(origin: carbonCenters[i], element: 6))
      
      var neighborTypes: [Int] = []
      var neighborCenters: [SIMD3<Float>] = []
      for j in 0..<carbonTypes[i] {
        let index = Int(carbonNeighbors[i][j])
        neighborTypes.append(carbonTypes[index])
        neighborCenters.append(carbonCenters[index])
        
        if i < index {
          bonds.append(SIMD2(
            Int32(truncatingIfNeeded: i),
            Int32(truncatingIfNeeded: index)))
        }
      }
      
      func addHydrogen(direction: SIMD3<Float>) {
        let hydrogenCenter = carbonCenters[i] + chBondLength * direction
        atoms.append(MRAtom(origin: hydrogenCenter, element: 1))
        bonds.append(SIMD2(
          Int32(truncatingIfNeeded: i),
          Int32(truncatingIfNeeded: bonds.count)))
      }
      
      switch carbonTypes[i] {
      case 4:
        break
      case 3:
        let sideAB = neighborCenters[1] - neighborCenters[0]
        let sideAC = neighborCenters[2] - neighborCenters[0]
        var normal = normalize(cross(sideAB, sideAC))
        
        let deltaA = carbonCenters[i] - neighborCenters[0]
        if dot(normal, deltaA) < 0 {
          normal = -normal
        }
        
//        var midPoint = neighborCenters[0] + neighborCenters[1]
//        midPoint += neighborCenters[2]
//        midPoint /= 3
//        let midpointNormal = normalize(carbonCenters[i] - midPoint)
//        var midpointRotation = simd_quatf(from: normal, to: midpointNormal)
//        let rotation = simd_quatf(
//          angle: midpointRotation.angle / 1, axis: midpointRotation.axis)
//        normal = simd_act(midpointRotation, normal)
        
        addHydrogen(direction: normal)
      case 2:
        let midPoint = (neighborCenters[1] + neighborCenters[0]) / 2
        guard distance(midPoint, carbonCenters[i]) > 0.001 else {
          fatalError("sp3 carbons are too close to 180 degrees.")
        }
        
        let normal = normalize(carbonCenters[i] - midPoint)
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
        
        let j = Int(carbonNeighbors[i][0])
        var referenceIndex: Int?
        for k in 0..<neighborTypes[0] {
          let index = Int(carbonNeighbors[j][k])
          if i != index {
            referenceIndex = index
            break
          }
        }
        guard let referenceIndex else {
          fatalError("Could not find valid neighbor index.")
        }
        let referenceCenter = carbonCenters[referenceIndex]
        let normal = normalize(carbonCenters[i] - carbonCenters[j])
        
        let referenceDelta = carbonCenters[j] - referenceCenter
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
