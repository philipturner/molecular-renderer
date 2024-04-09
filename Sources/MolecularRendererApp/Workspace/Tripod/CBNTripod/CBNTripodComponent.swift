//
//  CBNTripodComponent.swift
//  HDLTests
//
//  Created by Philip Turner on 12/30/23.
//

import Foundation
import HDL
import Numerics
import QuaternionModule

protocol CBNTripodComponent {
  var topology: Topology { get }
  
  // Call the compiler passes here, instead of doing them post-initialization.
  init()
}

extension CBNTripodComponent {
  // Check that all bonds are correctly assigned.
  func createBondRecord() -> [SIMD2<UInt8>: Int] {
    let bondsToAtomsMap = topology.map(.bonds, to: .atoms)
    var bondRecord: [SIMD2<UInt8>: Int] = [:]
    for atomList in bondsToAtomsMap {
      var atomicNumbers = atomList.map {
        topology.atoms[Int($0)].atomicNumber
      }
      atomicNumbers.sort()
      
      let key = SIMD2(atomicNumbers[0], atomicNumbers[1])
      var value = bondRecord[key] ?? 0
      value += 1
      bondRecord[key] = value
    }
    return bondRecord
  }
}

// This extension is used by multiple files in the CBNTripod folder.
extension Quaternion<Float> {
  init(from start: SIMD3<Float>, to end: SIMD3<Float>) {
    func cross(_ _self: SIMD3<Float>, _ other: SIMD3<Float>) -> SIMD3<Float> {
      let yzx = SIMD3<Int>(1,2,0)
      let zxy = SIMD3<Int>(2,0,1)
      return (_self[yzx] * other[zxy]) - (_self[zxy] * other[yzx])
    }
    
    // Source: https://stackoverflow.com/a/1171995
    let a = cross(start, end)
    let xyz = a
    let v1LengthSq = (start * start).sum()
    let v2LengthSq = (end * end).sum()
    let w = sqrt(v1LengthSq + v2LengthSq) + (start * end).sum()
    self.init(real: w, imaginary: xyz)
    
    guard let normalized = self.normalized else {
      fatalError("Could not normalize the quaternion.")
    }
    self = normalized
  }
}
