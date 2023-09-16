//
//  KeyFrame.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/15/23.
//

import Foundation

/// Unstable API; do not use this type.
public enum _Motion {
  case linear(SIMD3<Float>)
  case rotary(SIMD3<Float>, Float) // second argument is number of rotations
}

/// Unstable API; do not use this type.
public enum _KeyFrame {
  case stationary([SIMD3<Float>])
  case moving([SIMD3<Float>], [SIMD3<Float>], _Motion)
}
