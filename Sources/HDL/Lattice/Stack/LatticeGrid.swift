//
//  LatticeGrid.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/23/23.
//

protocol LatticeMask {
  associatedtype Storage: FixedWidthInteger
  var mask: [Storage] { get set }
  
  init(dimensions: SIMD3<Int32>, origin: SIMD3<Float>, normal: SIMD3<Float>)
  
  static func &= (lhs: inout Self, rhs: Self)
  static func |= (lhs: inout Self, rhs: Self)
}

extension LatticeMask {
  static func & (lhs: Self, rhs: Self) -> Self {
    var copy = lhs
    copy &= rhs
    return copy
  }
  
  static func | (lhs: Self, rhs: Self) -> Self {
    var copy = lhs
    copy |= rhs
    return copy
  }
}

protocol LatticeGrid {
  associatedtype Mask: LatticeMask
  associatedtype Storage: SIMD where Storage.Scalar == Int8
  
  var dimensions: SIMD3<Int32> { get }
  var entityTypes: [Storage] { get set }
  
  // Dimensions may be in a different coordinate space than the bounds that are
  // entered by the user.
  init(bounds: SIMD3<Float>, materialType: MaterialType)
  mutating func replace(with other: Int8, where mask: Mask)
  
  var entities: [Entity] { get }
}

extension LatticeGrid {
  // Takes the normals for the 6 planes [-x, +x, -y, +y, -z, +z] and cuts the
  // atoms off the initial grid that need to be removed.
  mutating func initializeBounds(
    _ bounds: SIMD3<Float>, normals: [SIMD3<Float>]
  ) {
    var union: Mask?
    for normalID in 0..<6 {
      var origin: SIMD3<Float> = .zero
      if normalID % 2 > 0 {
        origin = bounds
      }
      let normal = normals[normalID]
      let mask = Self.Mask(
        dimensions: self.dimensions, origin: origin, normal: normal)
      
      if union == nil {
        union = mask
      } else {
        union! |= mask
      }
    }
    self.replace(with: 0, where: union!)
  }
}
