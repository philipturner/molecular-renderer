//
//  HexagonalMask.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/25/23.
//

struct HexagonalMask: LatticeMask {
  var mask: [UInt16]
  
  /// Create a mask using a plane.
  ///
  /// The dimensions for this grid will appear very lopsided. `x` increments by
  /// one roughly every 2 hexagons in the `h` direction. Meanwhile, `y`
  /// increments by one exactly every hexagon in the `k` direction. This is the
  /// most direct way to represent the underlying storage.
  init(
    dimensions: SIMD3<Int32>,
    origin: SIMD3<Float>,
    normal untransformedNormal0: SIMD3<Float>
  ) {
    var normal0 = unsafeBitCast(
      (untransformedNormal0), to: SIMD4<Float>.self)
    normal0.lowHalf -= 0.5 * SIMD2(normal0[1], normal0[0])
    let normal = unsafeBitCast(normal0, to: SIMD3<Float>.self)
    let untransformedOrigin = transformHKLtoHH2KL(origin)
    let untransformedNormal = transformHKLtoHH2KL(untransformedNormal0)
    
    // Initialize the mask with everything in the one volume, and filled. The
    // value should be overwritten somewhere in the inner loop.
    mask = Array(repeating: 0x0FFF, count: Int(
      dimensions.x * dimensions.y * dimensions.z))
    if all(normal .== 0) {
      // This cannot be evaluated. It is a permissible escape hatch to create a
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
        let offset = SIMD8<Int8>(0, 1, 2, 3, 4, 5, 6, 7) &- 1
        let y = SIMD8<Int32>(repeating: base) &+
        SIMD8<Int32>(truncatingIfNeeded: offset)
        
        let deltaY = SIMD8<Float>(y) * 0.5 - untransformedOrigin.y
        let deltaZ = Float(z) - untransformedOrigin.z
        var rhs = -deltaY * untransformedNormal.y
        rhs -= deltaZ * untransformedNormal.z
        let x = untransformedOrigin.x + (1 / untransformedNormal.x) * rhs
        
        // intersection x < 0      -> distance > 0, zero volume
        // intersection x > length -> distance < 0, one volume
        sdfVector[z &* sdfDimensionY / 8 &+ arrayIndex] = x
      }
    }
    
    for z in 0..<dimensions.z {
      // Note that the 'y' coordinate here starts at zero, while the actual
      // floating-point value should start at -0.5.
      for y in 0..<dimensions.y {
        let offsetY = SIMD4<UInt8>(0, 2, 0, 2)
        let offsetZ = SIMD4<UInt8>(0, 0, 1, 1)
        var searchY = SIMD4<Int32>(repeating: y)
        var searchZ = SIMD4<Int32>(repeating: z)
        searchY &+= SIMD4(truncatingIfNeeded: offsetY)
        searchZ &+= SIMD4(truncatingIfNeeded: offsetZ)
        let addresses = searchZ &* Int32(sdfDimensionY) &+ searchY
        
        var gathered: SIMD4<Float> = .zero
        for lane in 0..<4 {
          gathered[lane] = sdfScalar[Int(addresses[lane])]
        }
        let gatheredMin = gathered.min()
        let gatheredMax = gathered.max()
        let gatheredNaN =
        gathered[0].isNaN ||
        gathered[1].isNaN ||
        gathered[2].isNaN ||
        gathered[3].isNaN
        
        let parityOffset: Float = (y & 1 == 0) ? 1.5 : 0.0
        let loopOffset: Int32 = (y & 1 == 0) ? -1 : 0
        var baseAddress = (z &* dimensions.y &+ y)
        baseAddress = baseAddress &* dimensions.x
        let maxLoopSize = dimensions.x + loopOffset
        
        var loopStart: Int32 = 0
        var loopEnd = maxLoopSize
        var leftMask: UInt16 = normal.x < 0 ? .max : .zero
        var rightMask: UInt16 = normal.x > 0 ? .max : .zero
        if gatheredNaN {
          // pass
        } else if gatheredMin > 3 * Float(dimensions.x) || gatheredMax < 3 * 0 {
          var distance = Float(y - 1) * 0.5 - untransformedOrigin.y
          distance *= untransformedNormal.y
          distance += (Float(z) - untransformedOrigin.z) * untransformedNormal.z
          loopEnd = 0
          
          if distance > 0 {
            // "one" volume
            rightMask = .max
          } else {
            // "zero" volume
            rightMask = .zero
          }
        } else {
          // Add a floating-point epsilon to the gathered min/max, as the sharp
          // cutoff could miss atoms in the next cell, which lie perfectly on
          // the plane.
          if gatheredMin > 3 * 0 {
            loopStart = Int32((gatheredMin / 3 - 0.001).rounded(.down))
            loopStart = max(loopStart, 0)
          }
          if gatheredMax < 3 * Float(dimensions.x) {
            loopEnd = Int32((gatheredMax / 3 + 0.001).rounded(.up))
            loopEnd = min(loopEnd, dimensions.x)
          }
        }
        
        do {
          var x = Int32(0)
          var xa = Int32(0)
          while x < loopStart * 3 {
            mask[Int(baseAddress + xa)] = leftMask
            x += 3
            xa += 1
          }
        }
        do {
          var x = 3 * loopEnd
          var xa = loopEnd
          while x < 3 * dimensions.x {
            mask[Int(baseAddress + xa)] = rightMask
            x += 3
            xa += 1
          }
        }
        
        var x = 3 * loopStart
        var xa = loopStart
        while x < 3 * loopEnd {
          var lowerCorner = SIMD3(Float(x) + parityOffset,
                                  Float(y) - 1,
                                  Float(z))
          lowerCorner.y /= 2
          lowerCorner = transformHH2KLtoHKL(lowerCorner)
          
          let cellMask = HexagonalCell.intersect(
            origin: origin - lowerCorner,
            normal: normal)
          mask[Int(baseAddress + xa)] = cellMask
          x += 3
          xa += 1
        }
      }
    }
  }
}

extension HexagonalMask {
  static func &= (lhs: inout Self, rhs: Self) {
    guard lhs.mask.count == rhs.mask.count else {
      fatalError("Combined masks of different sizes.")
    }
    for elementID in lhs.mask.indices {
      lhs.mask[elementID] &= rhs.mask[elementID]
    }
  }
  
  static func |= (lhs: inout Self, rhs: Self) {
    guard lhs.mask.count == rhs.mask.count else {
      fatalError("Combined masks of different sizes.")
    }
    for elementID in lhs.mask.indices {
      lhs.mask[elementID] |= rhs.mask[elementID]
    }
  }
}
