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
  }
  
  private(set) var carbons: [CarbonCenter] = []
  
  init() {
    
  }
  
  mutating func addCarbon(_ carbon: CarbonCenter) {
    precondition(carbon.currentBondIndex == 4, "Bonds not fully specified.")
    carbons.append(carbon)
  }
  
  func makeAtoms() -> [MRAtom] {
    let bondIndices: [SIMD4<Int32>] = carbons.indices.map { i in
      let carbon = carbons[i]
      var matchedIndices = SIMD4<Int32>(repeating: -1)
      
      for j in carbons.indices where i != j {
        let origin = carbons[j].origin
        var distances: SIMD4<Float> = SIMD4(repeating: .infinity)
        for k in 0..<4 {
          distances[k] = distance_squared(carbon.bondDeltas[k], origin)
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
