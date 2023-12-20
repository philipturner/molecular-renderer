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
  // Only call this once per frame, otherwise there will be an error.
  public func setCamera(
    camera: MRCamera,
    lights: [MRLight],
    quality: MRQuality
  ) {
    self.previousArguments = currentArguments
    
    let maxRayHitTime: Float = 1.0 // range(0...100, 0.2)
    let minimumAmbientIllumination: Float = 0.07 // range(0...1, 0.01)
    let diffuseReflectanceScale: Float = 0.5 // range(0...1, 0.1)
    let decayConstant: Float = 2.0 // range(0...20, 0.25)
    
    precondition(lights.count < UInt16.max, "Too many lights.")
    
    var totalDiffuse: Float = 0
    var totalSpecular: Float = 0
    for light in lights {
      totalDiffuse += Float(light.diffusePower)
      totalSpecular += Float(light.specularPower)
    }
    self.lights = (lights.map { _light in
      var light = _light
      
      // Normalize so nothing causes oversaturation.
      let diffuse = Float(light.diffusePower) / totalDiffuse
      let specular = Float(light.specularPower) / totalSpecular
      light.diffusePower = Float16(diffuse)
      light.specularPower = Float16(specular)
      light.resetMask()
      
      // Mark camera-centered lights as something to render more efficiently.
      if sqrt(distance_squared(light.origin, camera.position)) < 1e-3 {
        #if arch(arm64)
        var diffuseMask = light.diffusePower.bitPattern
        diffuseMask |= 0x1
        light.diffusePower = Float16(bitPattern: diffuseMask)
        #endif
      }
      return light
    })
    
    // Quality coefficients are calibrated against 640x640 -> 1280x1280
    // resolution.
    var screenMagnitude = Float(intermediateSize.x * intermediateSize.y)
    if offline {
      screenMagnitude /= 4
    } else {
      screenMagnitude *= Float(upscaleFactor! * upscaleFactor!)
    }
    screenMagnitude = sqrt(screenMagnitude) / 1280
    let qualityCoefficient = quality.qualityCoefficient * screenMagnitude
    
    // Create the FOV and rotation matrix from user-supplied arguments.
    let fovMultiplier = self.fovMultiplier(fovDegrees: camera.fovDegrees)
    let rotation = simd_float3x3(
      camera.rotation.0, camera.rotation.1, camera.rotation.2)
    
    self.currentArguments = Arguments(
      fovMultiplier: fovMultiplier,
      positionX: camera.position.x,
      positionY: camera.position.y,
      positionZ: camera.position.z,
      rotation: rotation,
      jitter: jitterOffsets,
      frameSeed: UInt32.random(in: 0...UInt32.max),
      numLights: UInt16(lights.count),
      
      minSamples: Float16(quality.minSamples),
      maxSamples: Float16(quality.maxSamples),
      qualityCoefficient: Float16(qualityCoefficient),
      
      maxRayHitTime: maxRayHitTime,
      exponentialFalloffDecayConstant: decayConstant,
      minimumAmbientIllumination: minimumAmbientIllumination,
      diffuseReflectanceScale: diffuseReflectanceScale,
      
      denseDims: .zero)
    
    let desiredSize = 3 * lights.count * MemoryLayout<MRLight>.stride
    if lightsBuffer.length < desiredSize {
      var newLength = lightsBuffer.length
      while newLength < desiredSize {
        newLength = newLength << 1
      }
      lightsBuffer = device.makeBuffer(length: newLength)!
    }
  }
}
