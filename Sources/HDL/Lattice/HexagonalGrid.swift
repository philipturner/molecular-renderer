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

/// The larger set of columns is typically half cut-off at either cap.
///
/// `firstRowStaggered` is equivalent to `firstRowOrigin`, but with some extra
/// padding for atoms cut off by the hexagonal zigzag on the very bottom. At
/// first glance, one would intuit that most hexagonal grids use the staggered
/// parity.
///
/// This type was originally deemed necessary, but it ended up unused in the
/// final design. It remains here as reference.
enum HexagonalGridParity: Int32 {
  /// First row and column are larger than second.
  case firstRowOrigin = 0
  
  /// Second row and column are larger than first.
  case firstRowStaggered = 1
}

fileprivate func transformHH2KLtoHKL(_ input: SIMD3<Float>) -> SIMD3<Float> {
  var output = SIMD3(1, 0, 0) * input.x
  output += SIMD3(1, 2, 0) * input.y
  output += SIMD3(0, 0, 1) * input.z
  return output
}

fileprivate func transformHKLtoHH2KL(_ input: SIMD3<Float>) -> SIMD3<Float> {
  var output = SIMD3(1, 0, 0) * input.x
  output += SIMD3(-0.5, 0.5, 0) * input.y
  output += SIMD3(0, 0, 1) * input.z
  return output
}

fileprivate func transformHKLtoXYZ(_ input: SIMD3<Float>) -> SIMD3<Float> {
  var output = SIMD3(1, 0, 0) * input.x
  output += SIMD3(-0.5, 0.8660254038, 0) * input.y
  output += SIMD3(0, 0, 1) * input.z
  return output
}

struct HexagonalCell {
  // Multiply the plane's origin by [3, 3, 8] and direction by [8, 8, 3].
  // Span: [0 -> 2h], [0 -> 2k], [0 -> l]
  static let x0 = SIMD8<Float>(2, 4, 5, 4, 2, 1, 1, 2)
  static let y0 = SIMD8<Float>(1, 2, 4, 5, 4, 2, 2, 1)
  static let z0 = SIMD8<Float>(0, 1, 0, 1, 0, 1, 4, 5)
  
  // Ring: x = [2, 4, 5, 4, 2, 1, repeat]
  //       y = [1, 2, 4, 5, 4, 2, repeat]
  //       z = [0, 1, 0, 1, 0, 1, 5, 4, 5, 4, 5, 4]
  static let x1 = SIMD4<Float>(4, 5, 4, 2)
  static let y1 = SIMD4<Float>(2, 4, 5, 4)
  static let z1 = SIMD4<Float>(4, 5, 4, 5)
  
  /// Binary mask corresponding to the plane's "one volume" and "zero volume".
  /// - Parameter origin: The origin in HKL space.
  /// - Parameter normal: The origin in HKL space, modified with the -0.5
  ///   transformation (see the comments in the function body).
  static func intersect(
    origin: SIMD3<Float>,
    normal: SIMD3<Float>
  ) -> SIMD16<UInt8> {
    // r, r0, n are the original position in HKL space.
    // M is the transform from HKL to XYZ.
    //   (r - r0) * n  = 0 <- doesn't work
    // (Mr - Mr0) * Mn = 0 <- does work
    //
    // M(r - r0) * Mn = 0
    // (M(r - r0))^T Mn = 0
    // (r - r0)^T (M^T M) n = 0
    // pre-compute (M^T M) n, then dot with (r - r0)
    //
    // M^T M = |  1  -0.5 |
    //         | -0.5 1   |
    // In other words, subtract half of [n2, n1] from [n1, n2].
    let scaledOrigin = origin * SIMD3(3, 3, 8)
    let scaledNormal = normal * SIMD3(8, 8, 3)
    
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
    
    var mask0: SIMD8<Int32> = .zero
    var mask1: SIMD4<Int32> = .zero
    mask0.replace(with: SIMD8.one, where: dotProduct0 .> 0)
    mask1.replace(with: SIMD4.one, where: dotProduct1 .> 0)
    let output0 = SIMD8<UInt8>(truncatingIfNeeded: mask0)
    let output1 = SIMD4<UInt8>(truncatingIfNeeded: mask1)
    return SIMD16(
      lowHalf: output0,
      highHalf: SIMD8(lowHalf: output1, highHalf: .zero))
  }
}

struct HexagonalMask: LatticeMask {
  var mask: [SIMD16<UInt8>]
  
  /// Create a mask using a plane.
  ///
  /// The dimensions for this grid will appear very lopsided. `x` increments by
  /// one roughly every 2 hexagons in the `h` direction. Meanwhile, `y`
  /// increments by one exactly every hexagon in the `k` direction. This is the
  /// most direct way to represent the underlying storage.
  ///
  /// This function currently requires h/h + 2k/l planes. It will be changed
  /// once the shape generator changes to something based on hexagons.
  init(
    dimensions: SIMD3<Int32>,
    origin untransformedOrigin: SIMD3<Float>,
    normal untransformedNormal: SIMD3<Float>
  ) {
    let origin = transformHH2KLtoHKL(untransformedOrigin)
    var normal0 = unsafeBitCast(
      transformHH2KLtoHKL(untransformedNormal), to: SIMD4<Float>.self)
    normal0.lowHalf -= 0.5 * SIMD2(normal0[1], normal0[0])
    let normal = unsafeBitCast(normal0, to: SIMD3<Float>.self)
    
    // Initialize the mask with everything in the one volume. The full mask
    // prevents the entity types from being set to "empty".
    mask = Array(repeating: SIMD16(repeating: 0), count: Int(
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
        let rhs = -deltaY * untransformedNormal.y - deltaZ * untransformedNormal.z
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
        var leftMask = SIMD16<UInt8>(
          repeating: untransformedNormal.x < 0 ? 255 : 0)
        var rightMask = SIMD16<UInt8>(
          repeating: untransformedNormal.x > 0 ? 255 : 0)
        if gatheredNaN {
          // pass
        } else if gatheredMin > 3 * Float(dimensions.x) || gatheredMax < 3 * 0 {
          var distance = Float(y - 1) * 0.5 - untransformedOrigin.y
          distance *= untransformedNormal.y
          distance += (Float(z) - untransformedOrigin.z) * untransformedNormal.z
          loopEnd = 0
          
          if distance > 0 {
            // "one" volume
            rightMask = SIMD16(repeating: 255)
          } else {
            // "zero" volume
            rightMask = SIMD16(repeating: 0)
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

struct HexagonalGrid: LatticeGrid {
  var dimensions: SIMD3<Int32>
  var entityTypes: [SIMD16<Int8>]
  var hexagonSideLength: Float
  var prismHeight: Float
  
  /// Create a mask using a plane.
  ///
  /// - Parameter bounds: In the HKL coordinate space.
  /// - Parameter material: The material type to use.
  init(bounds: SIMD3<Float>, material: MaterialType) {
    var repeatingUnit: SIMD16<Int8>
    switch material {
    case .elemental(let element):
      let scalar = Int8(clamping: element.rawValue)
      repeatingUnit = SIMD16(repeating: scalar)
    case .checkerboard(let a, let b):
      let scalarA = Int8(clamping: a.rawValue)
      let scalarB = Int8(clamping: b.rawValue)
      let unit = unsafeBitCast(SIMD2(scalarA, scalarB), to: UInt16.self)
      let repeated = SIMD8<UInt16>(repeating: unit)
      repeatingUnit = unsafeBitCast(repeated, to: SIMD16<Int8>.self)
    }
    repeatingUnit.highHalf.highHalf = SIMD4(repeating: 0)
    
    // Dimensions are in h/h2k/l for now.
    var transformedBounds = transformHKLtoHH2KL(bounds)
    transformedBounds = SIMD3(transformedBounds.x * 1.0 / 3,
                              transformedBounds.y * 2 + 1,
                              transformedBounds.z)
    dimensions = SIMD3<Int32>(transformedBounds.rounded(.up))
    
    // Add 1 to the x dimension for safety, until further investigation proves
    // it's fine for all adversarial cases. This is similar to how performance
    // was sacrificed with the SDF omission. Being possible to debug is the
    // priority at this development stage.
    dimensions.x += 1
    dimensions.replace(with: SIMD3.zero, where: dimensions .< 0)
    entityTypes = Array(repeating: repeatingUnit, count: Int(
      dimensions.x * dimensions.y * dimensions.z))
    
    // Base the lattice constants on diamond, so it can intermix perfectly in
    // mixed-phase crystalline structures.
    // a: 2.51 -> 2.52
    // c: 4.12 -> 4.12
    hexagonSideLength = Float(1.0 / 2).squareRoot() * 0.357
    prismHeight = Float(4.0 / 3).squareRoot() * 0.357
    
    // Intersect yourself with some h/h + 2k/l planes.
    let hMinus = (SIMD3<Float>(-1, 0, 0))
    let hPlus = (SIMD3<Float>(1, 0, 0))
    let h2kMinus = (SIMD3<Float>(0, -1, 0))
    let h2kPlus = (SIMD3<Float>(0, 1, 0))
    let lMinus = (SIMD3<Float>(0, 0, -1))
    let lPlus = (SIMD3<Float>(0, 0, 1))
    self.initializeBounds(transformHKLtoHH2KL(bounds), normals: [
      hMinus, hPlus, h2kMinus, h2kPlus, lMinus, lPlus
    ])
  }
  
  mutating func replace(with other: Int8, where mask: HexagonalMask) {
    var newValue = SIMD16(repeating: other)
    newValue.highHalf.highHalf = SIMD4(repeating: 0)
    
    for cellID in entityTypes.indices {
      let condition = mask.mask[cellID] .> 0
      entityTypes[cellID].replace(with: newValue, where: condition)
    }
  }
  
  var entities: [Entity] {
    var output: [Entity] = []
    let sqrt34 = Float(0.75).squareRoot()
    let outputScale = SIMD3<Float>(
      hexagonSideLength, hexagonSideLength, prismHeight
    )
    for z in 0..<dimensions.z {
      for y in 0..<dimensions.y {
        let parityOffset: Float = (y & 1 == 0) ? 1.5 : 0.0
        let loopOffset: Int32 = (y & 1 == 0) ? -1 : 0
        var baseAddress = (z &* dimensions.y &+ y)
        baseAddress = baseAddress &* dimensions.x
        
        for x in 0..<dimensions.x + loopOffset {
          var lowerCorner = SIMD3<Float>(SIMD3(x, y, z))
          lowerCorner.x *= 3
          lowerCorner.x += parityOffset
          lowerCorner.y -= 1
          lowerCorner.y /= 2
          
          lowerCorner = transformHH2KLtoHKL(lowerCorner)
          lowerCorner *= outputScale
          lowerCorner = transformHKLtoXYZ(lowerCorner)
          
          let cell = entityTypes[Int(baseAddress + x)]
          for lane in 0..<12 {
            guard cell[lane] != 0 else {
              continue
            }
            
            var x: Float
            var y: Float
            var z: Float
            if lane < 8 {
              x = HexagonalCell.x0[lane]
              y = HexagonalCell.y0[lane]
              z = HexagonalCell.z0[lane]
            } else {
              x = HexagonalCell.x1[lane - 8]
              y = HexagonalCell.y1[lane - 8]
              z = HexagonalCell.z1[lane - 8]
            }
            let type = EntityType(compactRepresentation: cell[lane])
            
            var position = SIMD3<Float>(x, y, z)
            position *= SIMD3<Float>(1.0 / 3, 1.0 / 3, 1.0 / 8)
            position *= outputScale
            position = transformHKLtoXYZ(position)
            position += lowerCorner
            
            let entity = Entity(
              position: position, type: type)
            output.append(entity)
          }
        }
      }
    }
    return output
  }
}

/// Test function that returns the initial grid. Try with:
/// - diamond
/// - moissanite
/// - germanium
public func Hexagonal_init(
  bounds: SIMD3<Float>, material: MaterialType
) -> [Entity] {
  HexagonalGrid(bounds: bounds, material: material).entities
}
