//
//  CBNTripodComponent.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/29/23.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

protocol CBNTripodComponent {
  var topology: Topology { get }
  
  // Call the compiler passes here, instead of doing them post-initialization.
  // The preconditions will eventually become XCTAssert invocations.
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
