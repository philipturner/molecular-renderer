//
//  MRCamera.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Accelerate
import Metal
import simd
import QuartzCore

// MARK: - MRCamera

public struct MRCamera {
  public var position: SIMD3<Float>
  public var rotation: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
  public var fovDegrees: Float
  
  public init(
    position: SIMD3<Float>,
    rotation: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>),
    fovDegrees: Float
  ) {
    self.position = position
    self.rotation = rotation
    self.fovDegrees = fovDegrees
  }
}

// MARK: - MRLight

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

// MARK: - MRQuality

/// A means to balance quality with performance.
///
/// Disable fancy effects:
/// - samples: 0...0
/// - coefficient: 0
///
/// Real-time global illumination:
/// - samples: 3...7
/// - coefficient: 30
///
/// Offline production renders:
/// - samples: 7...32
/// - coefficient: 100
public struct MRQuality {
  public var minSamples: Int
  public var maxSamples: Int
  public var qualityCoefficient: Float
  
  @inlinable
  public init(
    minSamples: Int,
    maxSamples: Int,
    qualityCoefficient: Float
  ) {
    self.minSamples = minSamples
    self.maxSamples = maxSamples
    self.qualityCoefficient = qualityCoefficient
  }
}

// MARK: - MRRenderer Methods

extension MRRenderer {
  public func setCamera(_ camera: MRCamera) {
    self.camera = camera
  }
  
  public func setLights(_ lights: [MRLight]) {
    self.lights = lights
  }
  
  public func setQuality(_ quality: MRQuality) {
    self.quality = quality
  }
}
