//
//  MRRenderer+Update.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Foundation
import simd

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
  
  var worldOrigin: SIMD3<Int16>
  var worldDimensions: SIMD3<Int16>
}

extension MRRenderer {
  // Perform any updating work that happens before encoding the rendering work.
  // This should be called as early as possible each frame, to hide any latency
  // between now and when it can encode the rendering work.
  func updateResources() {
    self.updateCamera(camera: camera, lights: lights, quality: quality)
    self.updateGeometry(time: time)
    self.accelBuilder.updateResources()
    
    self.jitterFrameID += 1
    self.jitterOffsets = makeJitterOffsets()
    self.textureIndex = (self.textureIndex + 1) % 2
    self.renderIndex = (self.renderIndex + 1) % 3
  }
  
  func updateGeometry(time: MRTime) {
    var atoms = atomProvider.atoms(time: time)
    
    if time.absolute.frames > 0,
       time.relative.frames > 0,
       accelBuilder.atoms.count == atoms.count {
      // TODO: Fuse this with the GPU kernel that reduces the bounding box.
      var newVectors = [SIMD3<Float>](repeating: .zero, count: atoms.count)
      for i in atoms.indices {
        let current = atoms[i]
        let previous = accelBuilder.atoms[i]
        let delta = current - previous
        newVectors[i] = unsafeBitCast(delta, to: SIMD3<Float>.self)
      }
      accelBuilder.motionVectors = newVectors
    } else {
      accelBuilder.motionVectors = Array(repeating: .zero, count: atoms.count)
    }
    
    self.accelBuilder.atoms = atoms
    self.accelBuilder.atomStyles = atomStyles
  }
  
  func updateCamera(
    camera: MRCamera,
    lights: [MRLight],
    quality: MRQuality
  ) {
    self.previousArguments = currentArguments
    
    var totalDiffuse: Float = 0
    var totalSpecular: Float = 0
    for light in lights {
      totalDiffuse += Float(light.diffusePower)
      totalSpecular += Float(light.specularPower)
    }
    
    precondition(lights.count < UInt16.max, "Too many lights.")
    self.lights = []
    for var light in lights {
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
      self.lights.append(light)
    }
    
    // Quality coefficients are calibrated against 640x640 -> 1280x1280
    // resolution.
    var screenMagnitude = Float(intermediateTextureSize * upscaleFactor)
    screenMagnitude *= screenMagnitude
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
      
      worldOrigin: .zero,
      worldDimensions: .zero)
    
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
