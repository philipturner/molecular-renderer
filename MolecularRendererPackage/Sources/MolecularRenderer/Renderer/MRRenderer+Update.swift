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
  var qualityCoefficient: Float
  
  var worldOrigin: SIMD3<Int16>
  var worldDimensions: SIMD3<Int16>
  
  var previousPosition: SIMD3<Float>
  var previousRotation: simd_float3x3
  var previousFOVMultiplier: Float
}

extension MRRenderer {
  func updateResources() {
    self.updateCamera(camera: camera)
    self.updateGeometry(time: time)
    self.bvhBuilder.updateResources()
    
    argumentContainer.jitterFrameID += 1
    self.textureIndex = (self.textureIndex + 1) % 2
    self.renderIndex = (self.renderIndex + 1) % 3
  }
  
  func updateGeometry(time: MRTime) {
    var atoms = atomProvider.atoms(time: time)
    
    // TODO: Fuse this with the GPU kernel that reduces the bounding box.
    if time.absolute.frames > 0,
       time.relative.frames > 0,
       bvhBuilder.atoms.count == atoms.count {
      var newVectors = [SIMD3<Float>](repeating: .zero, count: atoms.count)
      for i in atoms.indices {
        let current = atoms[i]
        let previous = bvhBuilder.atoms[i]
        let delta = current - previous
        newVectors[i] = unsafeBitCast(delta, to: SIMD3<Float>.self)
      }
      bvhBuilder.motionVectors = newVectors
    } else {
      bvhBuilder.motionVectors = Array(repeating: .zero, count: atoms.count)
    }
    
    self.bvhBuilder.atoms = atoms
    self.bvhBuilder.atomRadii = atomRadii
  }
  
  func updateCamera(
    camera: MRCamera
  ) {
    self.previousArguments = currentArguments
    
    // Quality coefficients are calibrated against 640x640 -> 1280x1280
    // resolution.
    var screenMagnitude = Float(intermediateTextureSize * upscaleFactor)
    screenMagnitude *= screenMagnitude
    screenMagnitude = sqrt(screenMagnitude) / 1280
    let qualityCoefficient = 30 * screenMagnitude
    
    let jitterOffsets = argumentContainer.createJitterOffsets()
    
    let fovMultiplier = ArgumentContainer
      .createFOVMultiplier(
        intermediateTextureSize: intermediateTextureSize,
        fovDegrees: camera.fovDegrees)
    
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
      qualityCoefficient: qualityCoefficient,
      
      worldOrigin: .zero,
      worldDimensions: .zero,
    
      previousPosition: .zero,
      previousRotation: simd_float3x3(diagonal: .zero),
      previousFOVMultiplier: .zero)
  }
}
