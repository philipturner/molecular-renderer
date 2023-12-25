//
//  Amplifier.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/27/23.
//

import Foundation
import MolecularRenderer
import QuaternionModule

#if false

// Initially designed to create an 8x8x8 cube duplicating a very small OpenMM
// simulation, to test the efficiency of a 3D video codec.
struct Amplifier {
  var offsets: [SIMD3<Float>] = []
  var rotations: [Quaternion<Float>] = []
  
  init() {
    for i in 0..<8 {
      for j in 0..<8 {
        for k in 0..<8 {
          var offset = SIMD3<Float>(SIMD3(i, j, k))
          offset += SIMD3(-3.5, -3.5, -3.5)
          offsets.append(offset)
        }
      }
    }
    
    srand48(79)
    for _ in 0..<512 {
      let angle = 2 * Double.pi * drand48()
      var axis: SIMD3<Double> = SIMD3(1, 1, 1)
      while cross_platform_length(axis) > 1 {
        axis = SIMD3(
          drand48(), drand48(), drand48())
      }
      let rotation = Quaternion<Float>(
        angle: Float(angle), axis: SIMD3<Float>(cross_platform_normalize(axis)))
      rotations.append(rotation)
    }
  }
  
  func apply(_ atoms: [MRAtom]) -> [MRAtom] {
    return (0..<512).flatMap {
      let offset = offsets[$0]
      let rotation = rotations[$0]
      return atoms.map {
        var copy = $0
        copy.origin = offset + rotation.act(on: copy.origin)
        return copy
      }
    }
  }
}

#endif
