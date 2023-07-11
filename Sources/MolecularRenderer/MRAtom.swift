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
  // TODO: Allow the user to enter ion charge as a flag, and change the atom's
  // radius based on a table of ionic radii (in MRAtomStyle) if it exists.
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

@_alignment(16)
public struct MRLight: Equatable {
  // Position in nm.
  public var x: Float
  public var y: Float
  public var z: Float
  
  // Parameters for Blinn-Phong shading, typically 1.
  public var diffusePower: Float16
  public var specularPower: Float16
  
  @inlinable @inline(__always)
  public init(
    origin: SIMD3<Float>,
    diffusePower: Float16,
    specularPower: Float16
  ) {
    (x, y, z) = (origin.x, origin.y, origin.z)
    self.diffusePower = diffusePower
    self.specularPower = specularPower
  }
  
  @inlinable @inline(__always)
  public mutating func resetMask() {
    #if arch(arm64)
    // Reserve 4 bits for flags.
    var diffuseMask = diffusePower.bitPattern
    var specularMask = specularPower.bitPattern
    diffuseMask &= ~0x3
    specularMask &= ~0x3
    self.diffusePower = Float16(bitPattern: diffuseMask)
    self.specularPower = Float16(bitPattern: specularMask)
    #else
    self.diffusePower = 0
    self.specularPower = 0
    #endif
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
}

