//
//  Geometry.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

import struct Metal.MTLPackedFloat3
import func Metal.MTLPackedFloat3Make

#if arch(arm64)

#else
// x86_64 is not supported; we are just bypassing a compiler error.
public typealias Float16 = UInt16
#endif

// MARK: - MRAtom

// Stores the origin, radius squared, and atom type.
@_alignment(16)
public struct MRAtom: Equatable {
  // Position in nm.
  public var x: Float
  public var y: Float
  public var z: Float
  
  // Radius in nm. This will be set internally to the MRRenderer.
  public var radiusSquared: Float16 = 0
  
  // Atomic number.
  public var element: UInt8
  
  // Flags to modify how the atom is rendered.
  public var flags: UInt8 = 0
  
  @inlinable @inline(__always)
  public init(
    origin: SIMD3<Float>,
    element: UInt8
  ) {
    self.x = origin.x
    self.y = origin.y
    self.z = origin.z
    self.element = element
  }
  
  @inlinable @inline(__always)
  public init(
    origin: SIMD3<Float>,
    element: Int
  ) {
    self.x = origin.x
    self.y = origin.y
    self.z = origin.z
    self.element = UInt8(element)
  }
  
  @inlinable @inline(__always)
  public var origin: SIMD3<Float> {
    get { SIMD3(x, y, z) }
    set {
      x = newValue.x
      y = newValue.y
      z = newValue.z
    }
  }
  
  @inlinable @inline(__always)
  public func getRadius(styles: UnsafePointer<MRAtomStyle>) -> Float16 {
    styles[Int(element)].radius
  }
  
  @inlinable @inline(__always)
  public func getColor(styles: UnsafePointer<MRAtomStyle>) -> SIMD3<Float16> {
    styles[Int(element)].color
  }
  
  @inlinable @inline(__always)
  public func getBoundingBox(
    styles: UnsafePointer<MRAtomStyle>
  ) -> MRBoundingBox {
    let radius = getRadius(styles: styles)
    let min = origin - Float(radius)
    let max = origin + Float(radius)
    return MRBoundingBox(
      min: MTLPackedFloat3Make(min.x, min.y, min.z),
      max: MTLPackedFloat3Make(max.x, max.y, max.z))
  }
}

// A finite-state machine that changes state based on time.
public protocol MRAtomProvider {
  mutating func atoms(time: MRTimeContext) -> [MRAtom]
}

// MARK: - MRAtomStyle

@_alignment(8)
public struct MRAtomStyle: Equatable {
  // Color in RGB color space.
  public var r: Float16
  public var g: Float16
  public var b: Float16
  
  // Radius in nm. We don't know the actual radius to 11 bits of precision, so
  // Float16 is fine.
  public var radius: Float16
  
  @inlinable @inline(__always)
  public var color: SIMD3<Float16> {
    get { SIMD3(r, g, b) }
    set {
      r = newValue[0]
      g = newValue[1]
      b = newValue[2]
    }
  }
  
  @inlinable @inline(__always)
  public init(color: SIMD3<Float16>, radius: Float16) {
    self.r = color[0]
    self.g = color[1]
    self.b = color[2]
    self.radius = radius
  }
}

// Each array must contain enough elements to correspond to the filled slots in
// `available`.
public protocol MRAtomStyleProvider {
  var styles: [MRAtomStyle] { get }
  var available: [Bool] { get }
}

// colors:
//   RGB color for each atom, ranging from 0 to 1 for each component.
// radii:
//   Enter all data in meters and Float32. They will be range-reduced to
//   nanometers and converted to Float16.
// available:
//   Whether each element has a style. Anything without a style uses `radii[0]`
//   and a black/magenta checkerboard pattern.
public func MRMakeAtomStyles(
  colors: [SIMD3<Float>],
  radii: [Float],
  available: [Bool]
) -> [MRAtomStyle] {
#if arch(x86_64)
    let atomColors: [SIMD3<Float16>] = []
#else
    let atomColors = colors.map(SIMD3<Float16>.init)
#endif
    let atomRadii = radii.map { $0 * 1e9 }.map(Float16.init)
    
    precondition(available.count == 127)
    return available.indices.map { i in
      let index = available[i] ? i : 0
      return MRAtomStyle(color: atomColors[index], radius: atomRadii[index])
    }
}

// MARK: - MRBoundingBox

// TODO: Remove MRBoundingBox from the API, and thus the Metal dependency.

@_alignment(8)
public struct MRBoundingBox {
  public var min: MTLPackedFloat3
  public var max: MTLPackedFloat3
  
  @inlinable @inline(__always)
  public init(min: MTLPackedFloat3, max: MTLPackedFloat3) {
    self.min = min
    self.max = max
  }
}
