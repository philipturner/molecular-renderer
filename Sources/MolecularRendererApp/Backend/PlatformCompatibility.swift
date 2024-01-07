//
//  MathUtilities.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/17/23.
//

import Foundation
import Numerics
import System

// MARK: - Math Utilities

// WARNING: Since we disabled whole-module optimization, none of these functions
// will actually inline. Always explicitly write out the functions in
// performance-critical loops.

@inline(__always)
func cross_platform_dot<T: Real & SIMDScalar>(
  _ x: SIMD2<T>, _ y: SIMD2<T>
) -> T {
  return (x * y).sum()
}

@inline(__always)
func cross_platform_dot<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> T {
  return (x * y).sum()
}

@_transparent
func cross_platform_cross<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> SIMD3<T> {
  // Source: https://en.wikipedia.org/wiki/Cross_product#Computing
  let s1 = x[1] * y[2] - x[2] * y[1]
  let s2 = x[2] * y[0] - x[0] * y[2]
  let s3 = x[0] * y[1] - x[1] * y[0]
  return SIMD3(s1, s2, s3)
}

@inline(__always)
func cross_platform_length<T: Real & SIMDScalar>(
  _ x: SIMD2<T>
) -> T {
  return cross_platform_dot(x, x).squareRoot()
}

@inline(__always)
func cross_platform_length<T: Real & SIMDScalar>(
  _ x: SIMD3<T>
) -> T {
  return cross_platform_dot(x, x).squareRoot()
}

@inline(__always)
func cross_platform_distance<T: Real & SIMDScalar>(
  _ x: SIMD2<T>, _ y: SIMD2<T>
) -> T {
  return cross_platform_length(y - x)
}

@inline(__always)
func cross_platform_min<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> SIMD3<T> {
  return x.replacing(with: y, where: y .< x)
}

@inline(__always)
func cross_platform_max<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> SIMD3<T> {
  return x.replacing(with: y, where: y .> x)
}

@inline(__always)
func cross_platform_distance<T: Real & SIMDScalar>(
  _ x: SIMD3<T>, _ y: SIMD3<T>
) -> T {
  return cross_platform_length(y - x)
}

@inline(__always)
func cross_platform_mix<T: Real & SIMDScalar>(
  _ x: T, _ y: T, _ t: T
) -> T {
  return y * t + x * (1 - t)
}

@inline(__always)
func cross_platform_normalize<T: Real & SIMDScalar>(
  _ x: SIMD3<T>
) -> SIMD3<T> {
  return x / (cross_platform_dot(x, x)).squareRoot()
}

@inline(__always)
func cross_platform_abs<T: Real & SIMDScalar>(
  _ x: SIMD3<T>
) -> SIMD3<T> {
  return x.replacing(with: -x, where: x .< 0)
}

@inline(__always)
func cross_platform_floor<T: Real & SIMDScalar>(
  _ x: SIMD3<T>
) -> SIMD3<T> {
  return x.rounded(.down)
}

struct cross_platform_float3x3 {
  var columns: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
  init(_ col1: SIMD3<Float>, _ col2: SIMD3<Float>, _ col3: SIMD3<Float>) {
    self.columns = (col1, col2, col3)
  }
  
  static func * (lhs: Self, rhs: SIMD3<Float>) -> SIMD3<Float> {
    lhs.columns.0 * rhs[0] +
    lhs.columns.1 * rhs[1] +
    lhs.columns.2 * rhs[2]
  }
}

struct cross_platform_double3x3 {
  var columns: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
  
  init(_ col1: SIMD3<Double>, _ col2: SIMD3<Double>, _ col3: SIMD3<Double>) {
    self.columns = (col1, col2, col3)
  }
  
  init(rows: [SIMD3<Double>]) {
    self.init(rows[0], rows[1], rows[2])
    self = self.transpose
  }
  
  init(diagonal: SIMD3<Double>) {
    self.init(SIMD3(diagonal[0], 0, 0),
              SIMD3(0, diagonal[1], 0),
              SIMD3(0, 0, diagonal[2]))
  }
  
  var transpose: cross_platform_double3x3 {
    cross_platform_double3x3(
      SIMD3(columns.0[0], columns.1[0], columns.2[0]),
      SIMD3(columns.0[1], columns.1[1], columns.2[1]),
      SIMD3(columns.0[2], columns.1[2], columns.2[2]))
  }
  
  // Source: https://stackoverflow.com/a/18504573
  var inverse: cross_platform_double3x3 {
    // double det = m(0, 0) * (m(1, 1) * m(2, 2) - m(2, 1) * m(1, 2)) -
    //              m(0, 1) * (m(1, 0) * m(2, 2) - m(1, 2) * m(2, 0)) +
    //              m(0, 2) * (m(1, 0) * m(2, 1) - m(1, 1) * m(2, 0));
    let determinant =
     +columns.0[0]*(columns.1[1]*columns.2[2]-columns.2[1]*columns.1[2])
    - columns.0[1]*(columns.1[0]*columns.2[2]-columns.1[2]*columns.2[0])
    + columns.0[2]*(columns.1[0]*columns.2[1]-columns.1[1]*columns.2[0])
    let invdet = 1/determinant
    
    // minv(0, 0) = (m(1, 1) * m(2, 2) - m(2, 1) * m(1, 2)) * invdet;
    // minv(0, 1) = (m(0, 2) * m(2, 1) - m(0, 1) * m(2, 2)) * invdet;
    // minv(0, 2) = (m(0, 1) * m(1, 2) - m(0, 2) * m(1, 1)) * invdet;
    let result00 = (columns.1[1]*columns.2[2]-columns.2[1]*columns.1[2])*invdet
    let result01 = (columns.0[2]*columns.2[1]-columns.0[1]*columns.2[2])*invdet
    let result02 = (columns.0[1]*columns.1[2]-columns.0[2]*columns.1[1])*invdet
    
    // minv(1, 0) = (m(1, 2) * m(2, 0) - m(1, 0) * m(2, 2)) * invdet;
    // minv(1, 1) = (m(0, 0) * m(2, 2) - m(0, 2) * m(2, 0)) * invdet;
    // minv(1, 2) = (m(1, 0) * m(0, 2) - m(0, 0) * m(1, 2)) * invdet;
    let result10 = (columns.1[2]*columns.2[0]-columns.1[0]*columns.2[2])*invdet
    let result11 = (columns.0[0]*columns.2[2]-columns.0[2]*columns.2[0])*invdet
    let result12 = (columns.1[0]*columns.0[2]-columns.0[0]*columns.1[2])*invdet
    
    // minv(2, 0) = (m(1, 0) * m(2, 1) - m(2, 0) * m(1, 1)) * invdet;
    // minv(2, 1) = (m(2, 0) * m(0, 1) - m(0, 0) * m(2, 1)) * invdet;
    // minv(2, 2) = (m(0, 0) * m(1, 1) - m(1, 0) * m(0, 1)) * invdet;
    let result20 = (columns.1[0]*columns.2[1]-columns.2[0]*columns.1[1])*invdet
    let result21 = (columns.2[0]*columns.0[1]-columns.0[0]*columns.2[1])*invdet
    let result22 = (columns.0[0]*columns.1[1]-columns.1[0]*columns.0[1])*invdet
    
    return cross_platform_double3x3(
      SIMD3(result00, result10, result20),
      SIMD3(result01, result11, result21),
      SIMD3(result02, result12, result22))
  }
  static func * (lhs: Self, rhs: SIMD3<Double>) -> SIMD3<Double> {
    lhs.columns.0 * rhs[0] +
    lhs.columns.1 * rhs[1] +
    lhs.columns.2 * rhs[2]
  }
  
  static func += (lhs: inout Self, rhs: Self) {
    lhs.columns.0 += rhs.columns.0
    lhs.columns.1 += rhs.columns.1
    lhs.columns.2 += rhs.columns.2
  }
  
  static func -= (lhs: inout Self, rhs: Self) {
    lhs.columns.0 -= rhs.columns.0
    lhs.columns.1 -= rhs.columns.1
    lhs.columns.2 -= rhs.columns.2
  }
  
  static func *= (lhs: inout Self, rhs: Double) {
    lhs.columns.0 *= rhs
    lhs.columns.1 *= rhs
    lhs.columns.2 *= rhs
  }
}

extension Quaternion {
  init(from start: SIMD3<RealType>, to end: SIMD3<RealType>) {
    // Source: https://stackoverflow.com/a/1171995
    let a = cross_platform_cross(start, end)
    let xyz = a
    let v1LengthSq = cross_platform_dot(start, start)
    let v2LengthSq = cross_platform_dot(end, end)
    let w = sqrt(v1LengthSq + v2LengthSq) + cross_platform_dot(start, end)
    self.init(real: w, imaginary: xyz)
    
    guard let normalized = self.normalized else {
      fatalError("Could not normalize the quaternion.")
    }
    self = normalized
  }
}

func quaternion_to_vector(_ quaternion: Quaternion<Float>) -> SIMD3<Float> {
  let angleAxis = quaternion.angleAxis
  let axis = angleAxis.axis
  
  if axis[0].isNaN || axis[1].isNaN || axis[2].isNaN {
    return .zero
  } else if angleAxis.length == 0 || angleAxis.angle.isNaN {
    return .zero
  } else {
    return angleAxis.angle * angleAxis.axis
  }
}

func vector_to_quaternion(_ vector: SIMD3<Float>) -> Quaternion<Float> {
  let length = (vector * vector).sum().squareRoot()
  if length < .leastNormalMagnitude {
    return Quaternion<Float>.zero
  } else {
    return Quaternion(angle: length, axis: vector / length)
  }
}

// Source: https://stackoverflow.com/a/18504573
func cross_platform_inverse3x3(
  _ columns: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
  let col = (SIMD3<Double>(columns.0),
             SIMD3<Double>(columns.1),
             SIMD3<Double>(columns.2))
  let determinant =
  col.0[0] * (col.1[1] * col.2[2] - col.2[1] * col.1[2]) -
  col.0[1] * (col.1[0] * col.2[2] - col.1[2] * col.2[0]) +
  col.0[2] * (col.1[0] * col.2[1] - col.1[1] * col.2[0])
  let invdet = 1 / determinant
  
  let result00 = (col.1[1] * col.2[2] - col.2[1] * col.1[2]) * invdet
  let result01 = (col.0[2] * col.2[1] - col.0[1] * col.2[2]) * invdet
  let result02 = (col.0[1] * col.1[2] - col.0[2] * col.1[1]) * invdet
  
  let result10 = (col.1[2] * col.2[0] - col.1[0] * col.2[2]) * invdet
  let result11 = (col.0[0] * col.2[2] - col.0[2] * col.2[0]) * invdet
  let result12 = (col.1[0] * col.0[2] - col.0[0] * col.1[2]) * invdet
  
  let result20 = (col.1[0] * col.2[1] - col.2[0] * col.1[1]) * invdet
  let result21 = (col.2[0] * col.0[1] - col.0[0] * col.2[1]) * invdet
  let result22 = (col.0[0] * col.1[1] - col.1[0] * col.0[1]) * invdet
  
  let column0 = SIMD3(result00, result10, result20)
  let column1 = SIMD3(result01, result11, result21)
  let column2 = SIMD3(result02, result12, result22)
  return (SIMD3<Float>(column0),
          SIMD3<Float>(column1),
          SIMD3<Float>(column2))
}

// MARK: - Time Utilities

// For lack of a better place to put them, bridging functions for cross-platform
// time utilities will go here.

fileprivate let startTime = ContinuousClock.now

func cross_platform_media_time() -> Double {
  let duration = ContinuousClock.now.duration(to: startTime)
  let seconds = duration.components.seconds
  let attoseconds = duration.components.attoseconds
  return -(Double(seconds) + Double(attoseconds) * 1e-18)
}

