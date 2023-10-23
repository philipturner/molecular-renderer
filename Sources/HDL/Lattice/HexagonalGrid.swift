//
//  HexagonalGrid.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

// Hexagonal Grid
//
// Source: https://www.redblobgames.com/grids/hexagons/#coordinates-doubled
// Similar to "Doubled coordinates", except halved and then compressed in the
// X direction (right -> 1/2 right) when storing in memory.

struct HexagonalCell {
  // Multiply the plane's origin by [3, 3, 8] and direction by [8, 8, 3].
  // Span: [0 -> 2h], [0 -> 2k], [0 -> l]
  static let x0 = SIMD8<Float>(2, 4, 5, 4, 2, 1, 2, 4)
  static let y0 = SIMD8<Float>(1, 2, 4, 5, 4, 2, 1, 2)
  static let z0 = SIMD8<Float>(0, 1, 0, 1, 0, 1, 4, 3)
  
  // Ring: x = [2, 4, 5, 4, 2, 1, repeat]
  //       y = [1, 2, 4, 5, 4, 2, repeat]
  //       z = [0, 1, 0, 1, 0, 1, 4, 3, 4, 3, 4, 3]
  static let x1 = SIMD4<Float>(5, 4, 2, 1)
  static let y1 = SIMD4<Float>(4, 5, 4, 2)
  static let z1 = SIMD4<Float>(4, 3, 4, 3)
  
  // Binary mask corresponding to the plane's "one volume" and "zero volume".
  static func intersect(
    origin: SIMD3<Float>,
    normal: SIMD3<Float>
  ) -> SIMD16<UInt8> {
    let scaledOrigin = origin * 4
    let scaledNormal = normal * 1
    
    let delta_x0 = x0 - scaledOrigin.x
    let delta_y0 = y0 - scaledOrigin.y
    let delta_z0 = z0 - scaledOrigin.z
    var dotProduct0 = delta_x0 * scaledNormal.x
    dotProduct0 += delta_y0 * scaledNormal.y
    dotProduct0 += delta_z0 * scaledNormal.z
    
    let delta_x1 = x1 - scaledOrigin.x
    let delta_y1 = y1 - scaledOrigin.y
    let delta_z1 = z1 - scaledOrigin.z
    var dotProduct1 = delta_x1 * scaledNormal.x
    dotProduct1 += delta_y1 * scaledNormal.y
    dotProduct1 += delta_z1 * scaledNormal.z
    
    var mask0: SIMD8<Int32> = .one
    var mask1: SIMD4<Int32> = .one
    mask0.replace(with: SIMD8.zero, where: dotProduct0 .> 0)
    mask1.replace(with: SIMD4.zero, where: dotProduct1 .> 0)
    let output0 = SIMD8<UInt8>(truncatingIfNeeded: mask0)
    let output1 = SIMD4<UInt8>(truncatingIfNeeded: mask1)
    return SIMD16(
      lowHalf: output0,
      highHalf: SIMD8(lowHalf: output1, highHalf: .zero))
  }
}

struct HexagonalMask {
  
}

struct HexagonalGrid {
  // Store some vectors of bitmasks: SIMD16<Int8>
}
