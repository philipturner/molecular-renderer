//
//  MM4_Parameters.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/29/23.
//

import Foundation

// "An improved force field (MM4) for saturated hydrocarbons"
// - 1996
// - Norman L. Allinger, Kuohsiang Chen, Jenn-Huei Lii
// https://doi.org/10.1002/(SICI)1096-987X(199604)17:5/6%3C642::AID-JCC6%3E3.0.CO;2-U
//
// "Molecular mechanics (MM4) study of saturated four-membered ring hydrocarbons"
// - 2002
// - Kuo-Hsiang Chen, Norman L Allinger
// - https://doi.org/10.1016/S0166-1280(01)00760-6
//
// "Molecular Mechanics (MM4) Studies on Unusually Long Carbon–Carbon Bond Distances in Hydrocarbons"
// - 2016
// - Norman L. Allinger, Jenn-Huei Lii, and Henry F. Schaefer, III
// - https://pubs.acs.org/doi/10.1021/acs.jctc.5b00926
//
// https://github.com/TinkerTools/tinker/blob/b6a58df90c5a66eceab92cc821d12b4dd27ca096/params/mm3.prm

extension MM4 {
  // 1 - alkane carbon
  // 5 - hydrogen
  // 56 - carbon in four-membered ring
  // 123 - carbon in five-membered ring
  
  struct Stretch {
    var stiffness: Float
    var length: Float
  }
  
  // This is getting untenable. We need something that can choose parameters by
  // analyzing the topology in source code.
  static let stretch: [[SIMD2<UInt16>: Stretch]] = [[
    SIMD2(1, 1): .init(stiffness: 4.55 * 100, length: 1.5270 * 1e-10),
    SIMD2(1, 5): .init(stiffness: 4.74 * 100, length: 1.1120 * 1e-10),
    SIMD2(1, 56): .init(stiffness: 3.95 * 100, length: 1.5108 * 1e-10),
    SIMD2(1, 123): .init(stiffness: 4.56 * 100, length: 1.5270 * 1e-10),
    
    SIMD2(5, 56): .init(stiffness: 4.70 * 100, length: 1.1090 * 1e-10),
    SIMD2(5, 123): .init(stiffness: 4.70 * 100, length: 1.1120 * 1e-10),
    
    SIMD2(56, 56): .init(stiffness: 4.49 * 100, length: 1.4750 * 1e-10),
    SIMD2(56, 123): .init(stiffness: 4.49 * 100, length: 1.5218 * 1e-10),
    
    SIMD2(123, 123): .init(stiffness: 4.99 * 100, length: 1.5290 * 1e-10),
  ], [
    // Four-membered rings
    SIMD2(56, 56): .init(stiffness: 4.20 * 100, length: 1.5393 * 1e-10),
  ]]
  
  struct Bend {
    var stiffness: Float
    var radians: Float
    
    init(stiffness: Float, degrees: Float) {
      self.stiffness = stiffness
      self.radians = degrees * .pi / 180
    }
  }
  
  static let bend1: [SIMD3<UInt16>: Bend] = [
    SIMD3(1, 1, 1): .init(stiffness: 0.740 * 100, degrees: 109.50)
  ]
}
