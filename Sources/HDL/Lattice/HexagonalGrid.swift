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

func transformHH2KLtoHKL(_ input: SIMD3<Float>) -> SIMD3<Float> {
  var output = SIMD3(1, 0, 0) * input.x
  output += SIMD3(1, 2, 0) * input.y
  output += SIMD3(0, 0, 1) * input.z
  return output
}

func transformHKLtoHH2KL(_ input: SIMD3<Float>) -> SIMD3<Float> {
  var output = SIMD3(1, 0, 0) * input.x
  output += SIMD3(-0.5, 0.5, 0) * input.y
  output += SIMD3(0, 0, 1) * input.z
  return output
}

func transformHKLtoXYZ(_ input: SIMD3<Float>) -> SIMD3<Float> {
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
  
  /// Binary mask corresponding to the plane's "zero volume" and "one volume".
  ///
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
    guard all(bounds.rounded(.up) .== bounds) else {
      fatalError("Bounds were not integers.")
    }
    
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
    
    var transformedBounds = transformHKLtoHH2KL(bounds)
    transformedBounds = SIMD3(transformedBounds.x * 1.0 / 3,
                              transformedBounds.y * 2 + 1,
                              transformedBounds.z)
    dimensions = SIMD3<Int32>(transformedBounds.rounded(.up))
    
    dimensions.replace(with: SIMD3.zero, where: dimensions .< 0)
    entityTypes = Array(repeating: repeatingUnit, count: Int(
      dimensions.x * dimensions.y * dimensions.z))
    
    // Base the lattice constants on diamond, so it can intermix perfectly in
    // mixed-phase crystalline structures.
    // a: 2.51 -> 2.52
    // c: 4.12 -> 4.12
    hexagonSideLength = Float(1.0 / 2).squareRoot() * 0.357
    prismHeight = Float(4.0 / 3).squareRoot() * 0.357
    
    // Intersect the lattice with some h/h + 2k/l planes.
    let hMinus = transformHH2KLtoHKL(SIMD3<Float>(-1, 0, 0))
    let hPlus = transformHH2KLtoHKL(SIMD3<Float>(1, 0, 0))
    let h2kMinus = transformHH2KLtoHKL(SIMD3<Float>(0, -1, 0))
    let h2kPlus = transformHH2KLtoHKL(SIMD3<Float>(0, 1, 0))
    let lMinus = transformHH2KLtoHKL(SIMD3<Float>(0, 0, -1))
    let lPlus = transformHH2KLtoHKL(SIMD3<Float>(0, 0, 1))
    self.initializeBounds((bounds), normals: [
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
public func Hexagonal_init(
  bounds: SIMD3<Float>, material: MaterialType
) -> [Entity] {
  HexagonalGrid(bounds: bounds, material: material).entities
}
