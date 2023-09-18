//
//  Animation.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/15/23.
//

import Foundation

/// A key frame for an animation of the geometry compilation.
///
/// An animation can help to visually debug the compiler, or illustrate how the
/// crystolecule was designed.
public enum AnimationKeyFrame {
  /// Keep the atoms still for a short period of time.
  case stationary([SIMD3<Float>])
  
  /// Animate the movement for a short period of time.
  ///
  /// Members:
  /// - First argument: the stationary atoms.
  /// - Second argument: the moving atoms.
  /// - Third argument: the type of motion.
  case moving([SIMD3<Float>], [SIMD3<Float>], AnimationMotion)
}

/// A type of motion during an animation.
public enum AnimationMotion {
  /// Make the atoms randomly fade away over time.
  ///
  /// Members:
  /// - First argument: the world origin when the cut was made.
  ///
  /// Tip: you can set the origin to somewhere unrelated to plane generation
  /// before calling `Cut()`. Doing so may put the camera in a better position.
  case fade(SIMD3<Float>)
  
  /// Reflect the atoms across an axis.
  ///
  /// Members:
  /// - First argument: the origin to reflect over.
  /// - Second argument: the direction to reflect across.
  case reflect(SIMD3<Float>, SIMD3<Float>)
  
  /// Rotate about an axis.
  ///
  /// Members:
  /// - First argument: the origin to rotate around.
  /// - Second argument: the direction to rotate around.
  /// - Third argument: the number of revolutions.
  case rotate(SIMD3<Float>, SIMD3<Float>, Float)
  
  /// Make the atoms move by a specified amount, relative to their current
  /// positions.
  case translate(SIMD3<Float>)
}
