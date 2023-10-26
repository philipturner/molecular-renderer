//
//  CubicMask.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/25/23.
//

struct CubicMask: LatticeMask {
  var mask: [SIMD8<UInt8>]
  
  /// Create a mask using a plane.
  init(dimensions: SIMD3<Int32>, origin: SIMD3<Float>, normal: SIMD3<Float>) {
    // Initialize the mask with everything in the one volume, and filled. The
    // value should be overwritten somewhere in the inner loop.
    mask = Array(repeating: SIMD8(repeating: 255), count: Int(
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
        let offset = SIMD8<UInt8>(0, 1, 2, 3, 4, 5, 6, 7)
        let y = SIMD8<Int32>(repeating: base) &+
        SIMD8<Int32>(truncatingIfNeeded: offset)
        
        let deltaY = SIMD8<Float>(y) - origin.y
        let deltaZ = Float(z) - origin.z
        let rhs = -deltaY * normal.y - deltaZ * normal.z
        let x = origin.x + (1 / normal.x) * rhs
        
        // intersection x < 0      -> distance > 0, zero volume
        // intersection x > length -> distance < 0, one volume
        sdfVector[z &* sdfDimensionY / 8 &+ arrayIndex] = x
      }
    }
    
    for z in 0..<dimensions.z {
      for y in 0..<dimensions.y {
        let offsetY = SIMD4<UInt8>(0, 1, 0, 1)
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
        
        var loopStart: Int32 = 0
        var loopEnd = dimensions.x
        var leftMask = SIMD8<UInt8>(repeating: normal.x < 0 ? 255 : 0)
        var rightMask = SIMD8<UInt8>(repeating: normal.x > 0 ? 255 : 0)
        if gatheredNaN {
          // pass
        } else if gatheredMin > Float(dimensions.x) || gatheredMax < 0 {
          var distance = (Float(y) - origin.y) * normal.y
          distance += (Float(z) - origin.z) * normal.z
          loopEnd = 0
          
          if distance > 0 {
            // "one" volume
            rightMask = SIMD8(repeating: 255)
          } else {
            // "zero" volume
            rightMask = SIMD8(repeating: 0)
          }
        } else {
          // Add a floating-point epsilon to the gathered min/max, as the sharp
          // cutoff could miss atoms in the next cell, which lie perfectly on
          // the plane.
          if gatheredMin > 0 {
            loopStart = Int32((gatheredMin - 0.001).rounded(.down))
            loopStart = max(loopStart, 0)
          }
          if gatheredMax < Float(dimensions.x) {
            loopEnd = Int32((gatheredMax + 0.001).rounded(.up))
            loopEnd = min(loopEnd, dimensions.x)
          }
        }
        
        let baseAddress = (z &* dimensions.y &+ y) &* dimensions.x
        for x in 0..<loopStart {
          mask[Int(baseAddress + x)] = leftMask
        }
        for x in loopEnd..<dimensions.x {
          mask[Int(baseAddress + x)] = rightMask
        }
        
        var lowerCorner = SIMD3<Float>(0, Float(y), Float(z))
        for x in loopStart..<loopEnd {
          lowerCorner.x = Float(x)
          
          let cellMask = CubicCell.intersect(
            origin: origin - lowerCorner, normal: normal)
          mask[Int(baseAddress + x)] = cellMask
        }
      }
    }
  }
}
