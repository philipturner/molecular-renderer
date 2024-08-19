//
//  Geometry.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

import Foundation

public protocol MRAtomProvider {
  func atoms(time: MRTime) -> [SIMD4<Float>]
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
