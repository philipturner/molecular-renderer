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

@_alignment(16)
struct Arguments {
  var fovMultiplier: Float
  var positionX: Float
  var positionY: Float
  var positionZ: Float
  var rotation: simd_float3x3
  var jitter: SIMD2<Float>
  var frameSeed: UInt32
  var numLights: UInt16
  
  var minSamples: Float16
  var maxSamples: Float16
  var qualityCoefficient: Float16
  
  var maxRayHitTime: Float
  var exponentialFalloffDecayConstant: Float
  var minimumAmbientIllumination: Float
  var diffuseReflectanceScale: Float
  
  var denseDims: SIMD3<UInt16>
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
  
  private func fovMultiplier(fovDegrees: Float) -> Float {
    // NOTE: This currently assumes the image is square. We eventually need to
    // support rectangular image sizes for e.g. 1920x1080 video.
    
    // How many pixels exist in either direction.
    let fov90Span = 0.5 * Float(intermediateSize.x)
    
    // Larger FOV means the same ray will reach an angle farther away from the
    // center. 1 / fovSpan is larger, so fovSpan is smaller. The difference
    // should be the ratio between the tangents of the two half-angles. And
    // one side of the ratio is tan(90 / 2) = 1.0.
    let fovRadians: Float = fovDegrees * .pi / 180
    let halfAngleTangent = tan(fovRadians / 2)
    let halfAngleTangentRatio = halfAngleTangent / 1.0
    
    // Let A = fov90Span
    // Let B = pixels covered by the 45° boundary in either direction.
    // Ray = ((pixelsRight, pixelsUp) * fovMultiplier, -1)
    //
    // FOV / 2 < 45°
    // - edge of image is ray (<1, <1, -1)
    // - A = 100 pixels
    // - B = 120 pixels (off-screen)
    // - fovMultiplier = 1 / 120 = 1 / B
    // FOV / 2 = 45°
    // - edge of image is ray (1, 1, -1)
    // - fovMultiplier = unable to determine
    // FOV / 2 > 45°
    // - edge of image is ray (>1, >1, -1)
    // - A = 100 pixels
    // - B = 80 pixels (well within screen bounds)
    // - fovMultiplier = 1 / 80 = 1 / B
    
    // Next: what is B as a function of fov90Span and halfAngleTangentRatio?
    // FOV / 2 < 45°
    // - A = 100 pixels
    // - B = 120 pixels (off-screen)
    // - halfAngleTangentRatio = 0.8
    // - formula: B = A / halfAngleTangentRatio
    // FOV / 2 = 45°
    // - A = 100 pixels
    // - B = 100 pixels
    // - formula: cannot be determined
    // FOV / 2 > 45°
    // - edge of image is ray (>1, >1, -1)
    // - A = 100 pixels
    // - B = 80 pixels (well within screen bounds)
    // - halfAngleTangentRatio = 1.2
    // - formula: B = A / halfAngleTangentRatio
    //
    // fovMultiplier = 1 / B = 1 / (A / halfAngleTangentRatio)
    // fovMultiplier = halfAngleTangentRatio / fov90Span
    return halfAngleTangentRatio / fov90Span
  }
}
