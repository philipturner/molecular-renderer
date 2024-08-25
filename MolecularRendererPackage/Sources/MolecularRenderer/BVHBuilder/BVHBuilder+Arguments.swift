//
//  BVHBuilder+Arguments.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

struct BVHArguments {
  var worldOrigin: SIMD3<Int16> = .zero
  var worldDimensions: SIMD3<Int16> = .zero
}

extension BVHBuilder {
  func createBVHArguments() -> BVHArguments {
    var output = BVHArguments()
    output.worldOrigin = worldOrigin
    output.worldDimensions = worldDimensions
    return output
  }
}
