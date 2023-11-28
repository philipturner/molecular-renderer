//
//  CubicGrid.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

struct CubicCell {
  // Multiply the plane's origin by [4, 4, 4].
  // Span: [0 -> h], [0 -> k], [0 -> l]
  static let x0 = SIMD8<Float>(0, 1, 0, 1, 2, 3, 2, 3)
  static let y0 = SIMD8<Float>(0, 1, 2, 3, 0, 1, 2, 3)
  static let z0 = SIMD8<Float>(0, 1, 2, 3, 2, 3, 0, 1)
  
  static let flags = SIMD8<UInt8>(
    1 << 0, 1 << 1, 1 << 2, 1 << 3,
    1 << 4, 1 << 5, 1 << 6, 1 << 7)
  
  // Binary mask corresponding to the plane's "one volume" and "zero volume".
  static func intersect(
    origin: SIMD3<Float>,
    normal: SIMD3<Float>
  ) -> UInt8 {
    let scaledOrigin = origin * 4
    let scaledNormal = normal * 1
    
    let delta_x0 = x0 - scaledOrigin.x
    let delta_y0 = y0 - scaledOrigin.y
    let delta_z0 = z0 - scaledOrigin.z
    var dotProduct0 = delta_x0 * scaledNormal.x
    dotProduct0 += delta_y0 * scaledNormal.y
    dotProduct0 += delta_z0 * scaledNormal.z
    
    var mask0: SIMD8<Int32> = .zero
    mask0.replace(with: SIMD8(repeating: .max), where: dotProduct0 .> 0)
    let compressed = SIMD8<UInt8>(truncatingIfNeeded: mask0)
    return (compressed & CubicCell.flags).wrappedSum()
  }
}

struct CubicMask: LatticeMask {
  var mask: [UInt8]
  
  /// Create a mask using a plane.
  init(dimensions: SIMD3<Int32>, origin: SIMD3<Float>, normal: SIMD3<Float>) {
    // Initialize the mask with everything in the one volume, and filled. The
    // value should be overwritten somewhere in the inner loop.
    mask = Array(repeating: .max, count: Int(
      dimensions.x * dimensions.y * dimensions.z))
    if all(normal .== 0) {
      // This cannot be evaluated. It is a permissible escape hatch to create a
      // mask with no intersection.
      return
    }
    
    for z in 0..<dimensions.z {
      for y in 0..<dimensions.y {
        let baseAddress = (z &* dimensions.y &+ y) &* dimensions.x
        
        for x in 0..<dimensions.x {
          let lowerCorner = SIMD3<Float>(Float(x), Float(y), Float(z))
          
          let cellMask = CubicCell.intersect(
            origin: origin - lowerCorner, normal: normal)
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

struct CubicGrid: LatticeGrid {
  var dimensions: SIMD3<Int32>
  var entityTypes: [SIMD8<Int8>]
  var squareSideLength: Float
  
  /// Create a mask using a plane.
  init(bounds: SIMD3<Float>, materialType: MaterialType) {
    guard all(bounds.rounded(.up) .== bounds) else {
      fatalError("Bounds were not integers.")
    }
    
    var repeatingUnit: SIMD8<Int8>
    switch materialType {
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
    
    // Increase the bounds by a small amount, so atoms on the edge will be
    // present in the next cell.
    dimensions = SIMD3<Int32>((bounds + 0.001).rounded(.up))
    dimensions.replace(with: SIMD3.zero, where: dimensions .< 0)
    entityTypes = Array(repeating: repeatingUnit, count: Int(
      dimensions.x * dimensions.y * dimensions.z))
    
    // Fetch the lattice constant using the 'Constant' API.
    squareSideLength = Constant(.square) { materialType }
    
    self.initializeBounds(bounds, normals: [
      SIMD3<Float>(-1, 0, 0),
      SIMD3<Float>(1, 0, 0),
      SIMD3<Float>(0, -1, 0),
      SIMD3<Float>(0, 1, 0),
      SIMD3<Float>(0, 0, -1),
      SIMD3<Float>(0, 0, 1),
    ])
  }
  
  mutating func replace(with other: Int8, where mask: CubicMask) {
    let newValue = SIMD8(repeating: other)
    
    for cellID in entityTypes.indices {
      let compressed = mask.mask[cellID]
      let flags = CubicCell.flags & compressed
      
      var codes = entityTypes[cellID]
      let select = codes .!= 0
      codes.replace(with: newValue, where: flags .> 0 .& select)
      entityTypes[cellID] = codes
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
