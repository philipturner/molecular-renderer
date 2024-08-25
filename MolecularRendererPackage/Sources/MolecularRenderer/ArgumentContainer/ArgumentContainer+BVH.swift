//
//  ArgumentContainer+BVH.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

import Metal

// BVH arguments data structure.
struct BVHArguments {
  var worldOrigin: SIMD3<Int16> = .zero
  var worldDimensions: SIMD3<Int16> = .zero
}
