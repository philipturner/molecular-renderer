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

// MARK: - MRRenderer Methods

extension MRRenderer {
  public func setCamera(_ camera: MRCamera) {
    self.camera = camera
  }
}
