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
  ) -> SIMD8<UInt8> {
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

struct CubicMask {
  var mask: [SIMD8<UInt8>]
  
  /// Create a mask using a plane.
  init(dimensions: SIMD3<Int32>, origin: SIMD3<Float>, normal: SIMD3<Float>) {
    // Initialize the mask with everything in the one volume. The full mask
    // prevents the entity types from being set to "empty".
    mask = Array(repeating: SIMD8(repeating: 255), count: Int(
      dimensions.x * dimensions.y * dimensions.z))
    
    if all(normal .== 0) {
      // This cannot evaluated. It is a permissible escape hatch to create a
      // mask with no intersection.
      return
    }
    
    // Derivation of formula:
    // (r - r0) * n = 0
    // (x - x0)nx + (y - y0)ny + (z - z0)nz = 0
    // x = x0 + (1 / nx) (-(y - y0)ny - (z - z0)nz) = 0
    let sdfDimensionY = (Int(dimensions.y + 1) + 7) / 8 * 8
    let sdfDimensionZ = Int(dimensions.z + 1)
    var sdf: UnsafeMutableRawPointer = .allocate(
      byteCount: 4 * sdfDimensionY * sdfDimensionZ, alignment: 32)
    defer { sdf.deallocate() }
    
    // Solve the equations in parallel, 8 elements at a time.
    let sdfVector = sdf.assumingMemoryBound(to: SIMD8<Float>.self)
    let sdfScalar = sdf.assumingMemoryBound(to: Float.self)
    for z in 0..<sdfDimensionZ {
      for arrayIndex in 0..<sdfDimensionY / 8 {
        let base = Int32(truncatingIfNeeded: arrayIndex &* 8)
        let offset = SIMD8<UInt8>(0, 1, 2, 3, 4, 5, 6, 7)
        let y = SIMD8<Int32>(repeating: base) &+
        SIMD8<Int32>(truncatingIfNeeded: offset)
        
        let deltaY = SIMD8<Float>(y) - origin.y
        let deltaZ = Float(z) - origin.z
        let rhs = -deltaY * normal.y - deltaZ * normal.z
        let x = origin.x + (1 / normal.x) * rhs
        
        // intersection x < 0      -> distance > 0, zero volume
        // intersection x > length -> distance < 0, one volume
        sdfVector[z &* sdfDimensionY &+ arrayIndex &* 8] = x
      }
    }
    
    for z in 0..<sdfDimensionZ {
      for y in 0..<sdfDimensionY {
        let offsetY = SIMD4<UInt8>(0, 1, 0, 1)
        let offsetZ = SIMD4<UInt8>(0, 0, 1, 1)
        var searchY = SIMD4<Int32>(repeating: Int32(y))
        var searchZ = SIMD4<Int32>(repeating: Int32(z))
        searchY &+= SIMD4(truncatingIfNeeded: offsetY)
        searchZ &+= SIMD4(truncatingIfNeeded: offsetZ)
        let addresses = searchZ &* Int32(sdfDimensionY) &+ Int32(sdfDimensionY)
        
        var gathered: SIMD4<Float> = .zero
        for lane in 0..<4 {
          gathered[lane] = sdfScalar[Int(addresses[lane])]
        }
        let minX = gathered.min()
        let maxX = gathered.max()
        let baseAddress = (z &* Int(dimensions.y) &+ y) &* Int(dimensions.x)
        
        var loopStart = Float(0)
        var loopEnd = Float(dimensions.x) - 1
        while loopStart <= minX - 1 {
          loopStart += 1
          let address = Int(loopStart) + baseAddress
          mask[address] = SIMD8(repeating: 255)
        }
        while loopEnd >= maxX + 1 {
          loopEnd -= 1
          let address = Int(loopEnd) + baseAddress
          mask[address] = SIMD8(repeating: 0)
        }
        
        var lowerCorner = SIMD3<Float>(0, Float(y), Float(z))
        while loopStart <= loopEnd {
          let address = Int(loopStart) + baseAddress
          lowerCorner.x = loopStart
          
          let cellMask = CubicCell.intersect(
            origin: origin - lowerCorner, normal: normal)
          mask[address] = cellMask
        }
      }
    }
  }
}

struct CubicGrid {
  // Store some vectors of bitmasks: SIMD8<Int8>
  // Map known bond order fractions to an enumerated set of negative integer
  // codes.
}
