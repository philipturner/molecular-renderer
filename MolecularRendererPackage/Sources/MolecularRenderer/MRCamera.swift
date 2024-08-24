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
  
  public func setQuality(_ quality: MRQuality) {
    self.quality = quality
  }
}
