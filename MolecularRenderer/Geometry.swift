//
//  Geometry.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

import Metal
import simd

let atomRadii: [Float] = [
  0, // 0
  0, // 1
  0, // 2
  0, // 3
  0, // 4
  0, // 5
  0.5, // 6
]

let atomColors: [SIMD3<Float16>] = [
  
]

// Stores the origin and uint8 atom type.
struct Sphere {
  private var data: SIMD4<Float>
  
  var origin: SIMD3<Float> {
    get { SIMD3(data.x, data.y, data.z) }
    set { data = SIMD4(newValue, data.w) }
  }
  
  var radiusSquared: Float {
    get {
      Self.unpackFourthPart(compressed: data.w).radiusSquared
    }
    set {
      data.w = Self.packFourthPart(
        radiusSquared: newValue, element: self.element)
    }
  }
  
  var element: UInt8 {
    get {
      Self.unpackFourthPart(compressed: data.w).element
    }
    set {
      data.w = Self.packFourthPart(
        radiusSquared: self.radiusSquared, element: newValue)
    }
  }
  
  private static func unpackFourthPart(
    compressed: Float
  ) -> (
    radiusSquared: Float, element: UInt8
  ) {
    let mask: UInt32 = 0x0000_00FF
    let radiusSquaredPart = compressed.bitPattern & ~mask
    let elementPart = compressed.bitPattern & mask
    return (
      Float(bitPattern: radiusSquaredPart),
      UInt8(truncatingIfNeeded: elementPart))
  }
  
  private static func packFourthPart(
    radiusSquared: Float,
    element: UInt8
  ) -> Float {
    let mask: UInt32 = 0x0000_00FF
    let radiusSquaredPart = radiusSquared.bitPattern & ~mask
    let elementPart = UInt32(element)
    return Float(bitPattern: radiusSquaredPart | elementPart)
  }
  
  init(origin: SIMD3<Float>, radius: Float) {
    self.data = .init(origin, radius * radius)
  }
}

struct BoundingBox {
  var min: MTLPackedFloat3
  var max: MTLPackedFloat3
}

struct SpherePrototype {
  var origin: SIMD3<Float>
  var radius: Float { atomRadii[Int(element)] }
  var element: UInt8
  
  func makeSphere() -> Sphere {
    return Sphere(origin: origin, radius: radius)
  }
  
  func makeBoundingBox() -> BoundingBox {
    let min = origin - radius
    let max = origin + radius
    return BoundingBox(
      min: MTLPackedFloat3Make(min.x, min.y, min.z),
      max: MTLPackedFloat3Make(max.x, max.y, max.z))
  }
}
