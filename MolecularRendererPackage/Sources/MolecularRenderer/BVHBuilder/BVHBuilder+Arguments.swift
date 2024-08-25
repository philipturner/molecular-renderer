//
//  BVHBuilder+Arguments.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

struct BVHArguments {
  var worldMinimum: SIMD3<Float> = .zero
  var worldMaximum: SIMD3<Float> = .zero
  var smallVoxelCount: SIMD3<UInt16> = .zero
}

extension BVHBuilder {
  // A scalar, unlike the one in BVH arguments.
  func createSmallVoxelCount() -> Int {
    let gridDimensions = SIMD3<Int>(
      truncatingIfNeeded: 4 &* (worldMaximum &- worldMinimum))
    
    var output: Int = 1
    output *= gridDimensions[0]
    output *= gridDimensions[1]
    output *= gridDimensions[2]
    return output
  }
}
