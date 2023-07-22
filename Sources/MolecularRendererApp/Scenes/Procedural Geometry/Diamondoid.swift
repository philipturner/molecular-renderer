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
  enum BondType: UInt8 {
    case cc = 1
    case ch = 2
    case vacant = 3
  }
  
  struct CarbonCenter {
    var origin: SIMD3<Float>
    var currentBondIndex: Int = 0
    var bondDeltas: simd_float4x3
    var bondFlags: SIMD4<UInt8>
    
    init(origin: SIMD3<Float>) {
      self.origin = origin
      self.bondDeltas = .init(.zero, .zero, .zero, .zero)
      self.bondFlags = .zero
    }
    
    mutating func addBond(_ delta: SIMD3<Float>, type: BondType) {
      precondition(currentBondIndex < 4, "Too many bonds.")
      bondDeltas[currentBondIndex] = delta
      bondFlags[currentBondIndex] = type.rawValue
      currentBondIndex += 1
    }
    
    mutating func addCarbonBond(_ delta: SIMD3<Float>) {
      addBond(delta, type: .cc)
    }
    
    mutating func addHydrogenBond(_ delta: SIMD3<Float>) {
      addBond(delta, type: .ch)
    }
  }
  
  private(set) var carbons: [CarbonCenter] = []
  
  init() {
    
  }
  
  mutating func addCarbon(_ carbon: CarbonCenter) {
    var copy = carbon
    for vacantIndex in carbon.currentBondIndex..<4 {
      copy.bondFlags[vacantIndex] = BondType.vacant.rawValue
    }
    carbons.append(copy)
  }
  
  func makeAtoms() -> [MRAtom] {
    let bondIndices: [SIMD4<Int32>] = carbons.indices.map { i in
      let carbon = carbons[i]
      var matchedIndices = SIMD4<Int32>(repeating: -1)
      
      for j in carbons.indices where i != j {
        var distances: SIMD4<Float> = SIMD4(repeating: .infinity)
        for k in 0..<4 {
          let target = carbon.origin + carbon.bondDeltas[k]
          distances[k] = distance_squared(target, carbons[j].origin)
        }
        distances = __tg_sqrt(distances)
        matchedIndices.replace(with: Int32(j), where: distances .< 0.001)
      }
      
      for k in 0..<4 {
        switch BondType(rawValue: carbon.bondFlags[k])! {
        case .cc:
          if matchedIndices[k] == -1 {
            fatalError("Did not find matching carbon (index \(i), bond \(k)).")
          }
        case .ch:
          matchedIndices[k] = -2
        case .vacant:
          matchedIndices[k] = -3
        }
      }
      return matchedIndices
    }
    
    for i in carbons.indices {
      for k in 0..<4 {
        let index = Int(bondIndices[i][k])
        precondition(index < carbons.count, "Invalid bond index.")
        if index >= 0 {
          let partnerIndices = bondIndices[index]
          guard any(partnerIndices .== Int32(i)) else {
            fatalError("Bond pair not bidirectional.")
          }
        }
      }
    }
    
    var atoms: [MRAtom] = []
    for carbon in carbons {
      atoms.append(MRAtom(origin: carbon.origin, element: 6))
      for k in 0..<4 {
        switch BondType(rawValue: carbon.bondFlags[k])! {
        case .cc:
          break
        case .ch:
          let origin = carbon.origin + carbon.bondDeltas[k]
          atoms.append(MRAtom(origin: origin, element: 1))
        case .vacant:
          break
        }
      }
    }
    
    return atoms
  }
}

// Rewriting the old Diamondoid API. We can do things like OpenMM minimizations
// on this data structure now.
struct _Diamondoid: MRAtomProvider {
  var _atoms: [MRAtom]
  var bonds: [SIMD2<Int32>]
  
  init(carbonCenters: [SIMD3<Float>]) {
    precondition(carbonCenters.count > 0, "Not enough carbons.")
    
    var minPosition: SIMD3<Float> = SIMD3(repeating: .infinity)
    var maxPosition: SIMD3<Float> = SIMD3(repeating: -.infinity)
    for center in carbonCenters {
      minPosition = min(center, minPosition)
      maxPosition = max(center, maxPosition)
    }
    
    // Build a uniform grid to search for neighbors in O(n) time.
    let cellSpaceMin = floor(minPosition * 4)
    let cellSpaceMax = floor(maxPosition * 4)
    let coordsOrigin = SIMD3<Int32>(cellSpaceMin)
    let boundingBox = SIMD3<Int32>(cellSpaceMax) &- coordsOrigin
    
    var grid = [SIMD2<Int32>](
      repeating: SIMD2(-1, 0),
      count: Int(boundingBox.x * boundingBox.y * boundingBox.z))
    var sectors: [SIMD16<Int32>] = []
    
    for (i, center) in carbonCenters.enumerated() {
      let cellSpaceFloor = floor(center * 4)
      let coords = SIMD3<Int32>(cellSpaceFloor)
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
    let ccBondLengthMax: Float = 0.170
    let chBondLength: Float = 0.109
    let sp3BondAngle: Float = 109.5 * .pi / 180
    
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
    
    _atoms = []
    bonds = []
    for i in carbonCenters.indices {
      _atoms.append(MRAtom(origin: carbonCenters[i], element: 6))
      
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
        _atoms.append(MRAtom(origin: hydrogenCenter, element: 1))
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
        if dot(normal, deltaA) > 0 {
          normal = -normal
        }
        addHydrogen(direction: normal)
      case 2:
        let midPoint = neighborCenters[1] - neighborCenters[0]
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
        let referenceIndex = Int(carbonNeighbors[j][0])
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
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    return _atoms
  }
}
