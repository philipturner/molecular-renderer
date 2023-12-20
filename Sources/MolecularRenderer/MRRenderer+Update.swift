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
  
  var maxRayHitTime: Float
  var exponentialFalloffDecayConstant: Float
  var minimumAmbientIllumination: Float
  var diffuseReflectanceScale: Float
  
  var denseDims: SIMD3<UInt16>
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
    if offline {
      self.jitterOffsets = SIMD2(repeating: 0)
    } else {
      self.jitterOffsets = makeJitterOffsets()
    }
    self.textureIndex = (self.textureIndex + 1) % 2
    self.renderIndex = (self.renderIndex + 1) % 3
  }
  
  func updateGeometry(time: MRTime) {
    if accelBuilder.sceneSize == .extreme, accelBuilder.builtGrid {
      return
    }
    
    var atoms = atomProvider.atoms(time: time)
    let styles = atomStyleProvider.styles
    let available = atomStyleProvider.available
    
    for i in atoms.indices {
      let element = Int(atoms[i].element)
      if available[element] {
        let radius = styles[element].radius
        atoms[i].radiusSquared = radius * radius
        atoms[i].flags = 0
      } else {
        let radius = styles[0].radius
        atoms[i].element = 0
        atoms[i].radiusSquared = radius * radius
        atoms[i].flags = 0x1 | 0x2
      }
    }
    
    if time.absolute.frames > 0 {
      guard accelBuilder.atoms.count == atoms.count else {
        fatalError(
          "Used motion vectors when last frame had different atom count.")
      }
      
      accelBuilder.motionVectors = (0..<atoms.count).map { i -> SIMD3<Float> in
        atoms[i].origin - accelBuilder.atoms[i].origin
      }
    } else {
      accelBuilder.motionVectors = Array(repeating: .zero, count: atoms.count)
    }
    
    self.accelBuilder.atoms = atoms
    self.accelBuilder.styles = styles
  }
  
  func updateCamera(
    camera: MRCamera,
    lights: [MRLight],
    quality: MRQuality
  ) {
    self.previousArguments = currentArguments
    
    let maxRayHitTime: Float = 1.0 // range(0...100, 0.2)
    let minimumAmbientIllumination: Float = 0.07 // range(0...1, 0.01)
    let diffuseReflectanceScale: Float = 0.5 // range(0...1, 0.1)
    let decayConstant: Float = 2.0 // range(0...20, 0.25)
    
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
