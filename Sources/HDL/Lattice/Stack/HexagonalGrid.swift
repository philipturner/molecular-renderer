//
//  HexagonalGrid.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

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
  
  static let flags = SIMD16<UInt16>(
    1 << 0, 1 << 1, 1 << 2, 1 << 3,
    1 << 4, 1 << 5, 1 << 6, 1 << 7,
    1 << 8, 1 << 9, 1 << 10, 1 << 11,
    1 << 12, 1 << 13, 1 << 14, 1 << 15)
  
  /// Binary mask corresponding to the plane's "zero volume" and "one volume".
  ///
  /// - Parameter origin: The origin in HKL space.
  /// - Parameter normal: The origin in HKL space, modified with the -0.5
  ///   transformation (see the comments in the function body).
  static func intersect(
    origin: SIMD3<Float>,
    normal: SIMD3<Float>
  ) -> UInt16 {
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
    
    var mask: SIMD16<Int32> = .zero
    mask.lowHalf.replace(with: SIMD8(repeating: .max), where: dotProduct0 .> 0)
    mask.highHalf.lowHalf
      .replace(with: SIMD4(repeating: .max), where: dotProduct1 .> 0)
    let compressed = SIMD16<UInt16>(truncatingIfNeeded: mask)
    return (compressed & HexagonalCell.flags).wrappedSum()
  }
}

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
    
    // Initialize the mask with everything in the one volume, and filled. The
    // value should be overwritten somewhere in the inner loop.
    mask = Array(repeating: 0x0FFF, count: Int(
      dimensions.x * dimensions.y * dimensions.z))
    if all(normal .== 0) {
      // This cannot be evaluated. It is a permissible escape hatch to create a
      // mask with no intersection.
      return
    }
    
    for z in 0..<dimensions.z {
      // Note that the 'y' coordinate here starts at zero, while the actual
      // floating-point value should start at -0.5.
      for y in 0..<dimensions.y {
        let parityOffset: Float = (y & 1 == 0) ? 1.5 : 0.0
        let loopOffset: Int32 = (y & 1 == 0) ? -1 : 0
        var baseAddress = (z &* dimensions.y &+ y)
        baseAddress = baseAddress &* dimensions.x
        
        for x in 0..<dimensions.x + loopOffset {
          var lowerCorner = SIMD3(Float(x) * 3 + parityOffset,
                                  Float(y) - 1,
                                  Float(z))
          lowerCorner.y /= 2
          lowerCorner = transformHH2KLtoHKL(lowerCorner)
          
          let cellMask = HexagonalCell.intersect(
            origin: origin - lowerCorner,
            normal: normal)
          mask[Int(baseAddress &+ x)] = cellMask
        }
      }
    }
  }
  
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

struct HexagonalGrid: LatticeGrid {
  var dimensions: SIMD3<Int32>
  var entityTypes: [SIMD16<Int8>]
  var hexagonSideLength: Float
  var prismHeight: Float
  
  /// Create a mask using a plane.
  ///
  /// - Parameter bounds: In the HKL coordinate space.
  /// - Parameter material: The material type to use.
  init(bounds: SIMD3<Float>, materialType: MaterialType) {
    guard all(bounds.rounded(.up) .== bounds) else {
      fatalError("Bounds were not integers.")
    }
    
    var repeatingUnit: SIMD16<Int8>
    switch materialType {
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
    
    var transformedBounds = transformHKLtoHH2KL(bounds)
    transformedBounds = SIMD3(transformedBounds.x * 1 / 3,
                              transformedBounds.y * 2 + 1,
                              transformedBounds.z)
    
    // Prevent floating-point error from causing incorrect rounding.
    guard let boundsX = Int(exactly: bounds.x) else {
      fatalError("Bounds x should always be an integer.")
    }
    transformedBounds.x = Float((boundsX + 2) / 3)
    
    dimensions = SIMD3<Int32>(transformedBounds.rounded(.up))
    dimensions.replace(with: SIMD3.zero, where: dimensions .< 0)
    entityTypes = Array(repeating: repeatingUnit, count: Int(
      dimensions.x * dimensions.y * dimensions.z))
    
    // Fetch the lattice constants using the 'Constant' API.
    hexagonSideLength = Constant(.hexagon) { materialType }
    prismHeight = Constant(.prism) { materialType }
    
    // Intersect the lattice with some h/h + 2k/l planes.
    let hMinus = transformHH2KLtoHKL(SIMD3<Float>(-1, 0, 0))
    let hPlus = transformHH2KLtoHKL(SIMD3<Float>(1, 0, 0))
    let h2kMinus = transformHH2KLtoHKL(SIMD3<Float>(0, -1, 0))
    let h2kPlus = transformHH2KLtoHKL(SIMD3<Float>(0, 1, 0))
    let lMinus = transformHH2KLtoHKL(SIMD3<Float>(0, 0, -1))
    let lPlus = transformHH2KLtoHKL(SIMD3<Float>(0, 0, 1))
    self.initializeBounds(bounds, normals: [
      hMinus, hPlus, h2kMinus, h2kPlus, lMinus, lPlus
    ])
  }
  
  mutating func replace(with other: Int8, where mask: HexagonalMask) {
    var newValue = SIMD16(repeating: other)
    newValue.highHalf.highHalf = SIMD4(repeating: 0)
    
    for cellID in entityTypes.indices {
      let compressed = mask.mask[cellID]
      let flags0 = CubicCell.flags & UInt8(truncatingIfNeeded: compressed)
      let flags1 = CubicCell.flags & UInt8(truncatingIfNeeded: compressed / 256)
      let flags = SIMD16(lowHalf: flags0, highHalf: flags1)
      
      var codes = entityTypes[cellID]
      let select = codes .!= 0
      codes.replace(with: newValue, where: flags .> 0 .& select)
      entityTypes[cellID] = codes
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

// MARK: - Utilities

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
