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

/// The larger set of columns is typically half cut-off at either cap.
///
/// `firstRowStaggered` is equivalent to `firstRowOrigin`, but with some extra
/// padding for atoms cut off by the hexagonal zigzag on the very bottom. At
/// first glance, one would intuit that most hexagonal grids use the staggered
/// parity.
enum HexagonalGridParity: Int32 {
  /// First row and column are larger than second.
  case firstRowOrigin = 0
  
  /// Second row and column are larger than first.
  case firstRowStaggered = 1
}

struct HexagonalMask {
  var mask: [SIMD16<UInt8>]
  
  /// Create a mask using a plane.
  ///
  /// > WARNING: The plane must be transformed from a h/k/l basis to a h/h+2k/l
  ///   basis before entering into this function. The transform matrix only has
  ///   fractions of 1/2, so there's no precision loss from floating-point
  ///   error.
  ///
  /// The dimensions for this grid will appear very lopsided. `x` increments by
  /// one roughly every 2 hexagons in the `h` direction. Meanwhile, `y`
  /// increments by one exactly every hexagon in the `k` direction. This is the
  /// most direct way to represent the underlying storage.
  init(dimensions: SIMD4<Int32>, origin: SIMD3<Float>, normal: SIMD3<Float>) {
    // In loops, it will perform an XOR with the parity's raw value.
    guard let parity = HexagonalGridParity(rawValue: dimensions.w) else {
      fatalError("Invalid parity in hexagonal plane dimensions.")
    }
    
    // Initialize the mask with everything in the one volume. The full mask
    // prevents the entity types from being set to "empty".
    mask = Array(repeating: SIMD16(repeating: 255), count: Int(
      dimensions.x * (dimensions.y * 2 - 1) * dimensions.z))
    
    if all(normal .== 0) {
      // This cannot evaluated. It is a permissible escape hatch to create a
      // mask with no intersection.
      return
    }
    
    // Derivation of formula:
    // (r - r0) * n = 0
    // (x - x0)nx + (y - y0)ny + (z - z0)nz = 0
    // x = x0 + (1 / nx) (-(y - y0)ny - (z - z0)nz) = 0
    let sdfDimensionY = (Int(dimensions.y * 2 + 1) + 7) / 8 * 8
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
        
        let deltaY = SIMD8<Float>(y) * 0.5 - origin.y
        let deltaZ = Float(z) - origin.z
        let rhs = -deltaY * normal.y - deltaZ * normal.z
        let x = origin.x + (1 / normal.x) * rhs
        
        // intersection x < 0      -> distance > 0, zero volume
        // intersection x > length -> distance < 0, one volume
        sdfVector[z &* sdfDimensionY &+ arrayIndex &* 8] = x
      }
    }
    
    for z in 0..<sdfDimensionZ {
      for y in 0..<sdfDimensionY * 2 - 1 {
        let offsetY = SIMD4<UInt8>(0, 2, 0, 2)
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
        
        // Non-staggered columns have one slot wasted in memory. This is
        // regardless of how wide the associated rows are. The memory wasting
        // is O(kl) in an O(hkl) context.
        //
        // Except - the data isn't packed by column. It's packed by row. No
        // extra slots are wasted, but understanding **why none are wasted** can
        // reinforce your comprehension of the data layout.
        var baseAddress = (z &* Int(dimensions.y * 2 - 1) &+ y)
        baseAddress = baseAddress &* Int(dimensions.x)
        
        var loopStart = Float(0)
        var loopEnd = 3 * Float(dimensions.x) - 3
        var parityOffset = Float(0)
        
        // Staggered rows have one slot wasted in memory. This is regardless of
        // how tall the associated columns are. The memory wasting is O(hl) in
        // an O(hkl) context.
        if (y & 1) ^ Int(parity.rawValue) == 1 {
          loopStart += 1.5
          loopEnd -= 1.5
          parityOffset = 1.5
        }
        while loopStart <= minX - 1 {
          loopStart += 1
          let address = Int(loopStart) + baseAddress
          mask[address] = SIMD16(repeating: 255)
        }
        while loopEnd >= maxX + 1 {
          loopEnd -= 1
          let address = Int(loopEnd) + baseAddress
          mask[address] = SIMD16(repeating: 0)
        }
        
        var lowerCorner = SIMD3<Float>(0, Float(y) * 0.5, Float(z))
        while loopStart <= loopEnd {
          let address = Int(loopStart - parityOffset) + baseAddress
          lowerCorner.x = loopStart
          
          // This matrix maps from h/h + 2k/l -> h/k/l.
          // | 1  1 |
          // | 0  2 |
          let columns = (SIMD2<Float>(1, 0),
                         SIMD2<Float>(1, 2))
          @inline(__always)
          func transform(_ input: SIMD3<Float>) -> SIMD3<Float> {
            var simd4 = SIMD4(input, 0)
            simd4.lowHalf = columns.0 * simd4.x + columns.1 * simd4.y
            return unsafeBitCast(simd4, to: SIMD3<Float>.self)
          }
          
          let cellMask = HexagonalCell.intersect(
            origin: transform(origin - lowerCorner),
            normal: transform(normal))
          mask[address] = cellMask
        }
      }
    }
  }
}

struct HexagonalGrid {
  // Store some vectors of bitmasks: SIMD16<Int8>
  // Map known bond order fractions to an enumerated set of negative integer
  // codes.
}
