//
//  CubicGrid.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

struct CubicCell {
  // Multiply the plane's origin by [4, 4, 4].
  // Span: [0 -> h], [0 -> k], [0 -> l]
  static let x0 = SIMD8<Float>(0, 1, 0, 2, 2, 1, 3, 3)
  static let y0 = SIMD8<Float>(0, 1, 2, 0, 2, 3, 1, 3)
  static let z0 = SIMD8<Float>(0, 1, 2, 2, 0, 3, 3, 1)
  
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

struct CubicMask: LatticeMask {
  var mask: [SIMD8<UInt8>]
  
  /// Create a mask using a plane.
  init(dimensions: SIMD3<Int32>, origin: SIMD3<Float>, normal: SIMD3<Float>) {
    // Initialize the mask with everything in the one volume. The full mask
    // prevents the entity types from being set to "empty".
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
        var searchY = SIMD4<Int32>(repeating: Int32(y))
        var searchZ = SIMD4<Int32>(repeating: Int32(z))
        searchY &+= SIMD4(truncatingIfNeeded: offsetY)
        searchZ &+= SIMD4(truncatingIfNeeded: offsetZ)
        let addresses = searchZ &* Int32(sdfDimensionY) &+ searchY
        
        var gathered: SIMD4<Float> = .zero
        for lane in 0..<4 {
          gathered[lane] = sdfScalar[Int(addresses[lane])]
        }
        var minX = gathered.min()
        var maxX = gathered.max()
        minX = max(minX, 0)
        maxX = min(maxX, Float(dimensions.x - 1))
        
        let baseAddress = (z &* Int32(dimensions.y) &+ y) &* Int32(dimensions.x)
        
        var loopStart = Float(0)
        var loopEnd = Float(dimensions.x) - 1
        
        // Deactivate the buggy code for now. There's NaNs somewhere.
//        while loopStart <= minX - 1 {
//          let address = Int32(loopStart) + baseAddress
//          mask[Int(address)] = SIMD8(repeating: 255)
//          loopStart += 1
//        }
//        while loopEnd >= maxX + 1 {
//          let address = Int32(loopEnd) + baseAddress
//          mask[Int(address)] = SIMD8(repeating: 0)
//          loopEnd -= 1
//        }
        
        var lowerCorner = SIMD3<Float>(0, Float(y), Float(z))
        while loopStart <= loopEnd {
          defer { loopStart += 1 }
          let address = Int32(loopStart) + baseAddress
          lowerCorner.x = loopStart
          
          let cellMask = CubicCell.intersect(
            origin: origin - lowerCorner, normal: normal)
          mask[Int(address)] = cellMask
        }
      }
    }
  }
  
  // TODO: Define some logical operations on masks.
}

// This should conform to a common protocol for manipulating grids. Cubic and
// hexagonal masks should follow a similar design.
struct CubicGrid: LatticeGrid {
  var dimensions: SIMD3<Int32>
  var entityTypes: [SIMD8<Int8>]
  var squareSideLength: Float
  
  /// Create a mask using a plane.
  init(bounds: SIMD3<Float>, material: MaterialType) {
    var repeatingUnit: SIMD8<Int8>
    switch material {
    case .elemental(let element):
      let scalar = Int8(clamping: element.rawValue)
      repeatingUnit = SIMD8(repeating: scalar)
    case .checkerboard(let a, let b):
      let scalarA = Int8(clamping: a.rawValue)
      let scalarB = Int8(clamping: b.rawValue)
      let unit = unsafeBitCast(SIMD2(scalarA, scalarB), to: UInt16.self)
      let repeated = SIMD4<UInt16>(repeating: unit)
      repeatingUnit = unsafeBitCast(repeated, to: SIMD8<Int8>.self)
    }
    
    dimensions = SIMD3<Int32>(bounds.rounded(.up))
    dimensions.replace(with: SIMD3.zero, where: dimensions .< 0)
    entityTypes = Array(repeating: repeatingUnit, count: Int(
      dimensions.x * dimensions.y * dimensions.z))
    
    // Set this to carbon lattice constants for now.
    squareSideLength = 0.357
    
    self.initializeBounds(bounds, normals: [
      SIMD3<Float>(-1, 0, 0),
      SIMD3<Float>(1, 0, 0),
      SIMD3<Float>(0, -1, 0),
      SIMD3<Float>(0, 1, 0),
      SIMD3<Float>(0, 0, -1),
      SIMD3<Float>(0, 0, 1),
    ])
  }
  
  // Cut() can be implemented by replacing with ".empty" in the mask's zero
  // volume.
  mutating func replace(with other: Int8, where mask: CubicMask) {
    let newValue = SIMD8(repeating: other)
    
    for cellID in entityTypes.indices {
      let condition = mask.mask[cellID] .== 0
      entityTypes[cellID].replace(with: newValue, where: condition)
    }
  }
  
  var entities: [Entity] {
    var output: [Entity] = []
    let outputTransform = (
      SIMD3<Float>(squareSideLength, 0, 0),
      SIMD3<Float>(0, squareSideLength, 0),
      SIMD3<Float>(0, 0, squareSideLength)
    )
    for z in 0..<dimensions.z {
      for y in 0..<dimensions.y {
        for x in 0..<dimensions.x {
          let lowerCorner = SIMD3<Float>(SIMD3(x, y, z))
          var cellID = z * dimensions.y + y
          cellID = cellID * dimensions.x + x
          
          let cell = entityTypes[Int(cellID)]
          for lane in 0..<8 {
            guard cell[lane] != 0 else {
              continue
            }
            
            let x = CubicCell.x0[lane] / 4
            let y = CubicCell.y0[lane] / 4
            let z = CubicCell.z0[lane] / 4
            let type = EntityType(compactRepresentation: cell[lane])
            
            var position = SIMD3<Float>(x, y, z)
            position += lowerCorner
            position =
            outputTransform.0 * position.x +
            outputTransform.1 * position.y +
            outputTransform.2 * position.z
            
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
public func Cubic_init(
  bounds: SIMD3<Float>, material: MaterialType
) -> [Entity] {
  CubicGrid(bounds: bounds, material: material).entities
}
