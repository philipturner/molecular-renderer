//
//  CubicGrid.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

struct CubicCell {
  // Multiply the plane's origin by [4, 4, 4].
  // Span: [0 -> h], [0 -> k], [0 -> l]
  static let x0 = SIMD8<Float>(0, 1, 0, 0, 1, 3, 3, 3)
  static let y0 = SIMD8<Float>(0, 0, 1, 0, 3, 1, 3, 3)
  static let z0 = SIMD8<Float>(0, 0, 0, 1, 3, 3, 1, 3)
  
  // Binary mask corresponding to the plane's "one volume" and "zero volume".
  static func intersect(
    origin: SIMD3<Float>,
    normal: SIMD3<Float>
  ) -> SIMD8<Int8> {
    let scaledOrigin = origin * 4
    let scaledNormal = normal * 1
    
    let delta_x0 = x0 - scaledOrigin.x
    let delta_y0 = y0 - scaledOrigin.y
    let delta_z0 = z0 - scaledOrigin.z
    var dotProduct0 = delta_x0 * scaledNormal.x
    dotProduct0 += delta_y0 * scaledNormal.y
    dotProduct0 += delta_z0 * scaledNormal.z
    
    var mask0: SIMD8<Int32> = .one
    mask0.replace(with: SIMD8.zero, where: dotProduct0 .> 0)
    return SIMD8(truncatingIfNeeded: mask0)
  }
}

struct CubicSDF {
  
}

struct CubicGrid {
  // Store some vectors of bitmasks: SIMD8<Int8>
}
