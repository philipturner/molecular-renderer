//
//  Geometry.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

import Foundation

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
  public var element: UInt16
  
  @inlinable @inline(__always)
  public init(
    origin: SIMD3<Float>,
    element: UInt8
  ) {
    self.x = origin.x
    self.y = origin.y
    self.z = origin.z
    self.element = UInt16(element)
  }
  
  @inlinable @inline(__always)
  public init(
    origin: SIMD3<Float>,
    element: Int
  ) {
    self.x = origin.x
    self.y = origin.y
    self.z = origin.z
    self.element = UInt16(element)
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
}

public protocol MRAtomProvider {
  func atoms(time: MRTime) -> [MRAtom]
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

// MARK: - MRRenderer Methods

extension MRRenderer {
  public func setAtomProvider(_ provider: MRAtomProvider) {
    self.atomProvider = provider
  }
  
  public func setAtomStyles(_ styles: [MRAtomStyle]) {
    self.atomStyles = styles
  }
}
