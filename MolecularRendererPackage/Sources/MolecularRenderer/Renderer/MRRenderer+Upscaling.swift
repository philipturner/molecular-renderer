//
//  MRRenderer+Upscaling.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

import Metal
import MetalFX

extension MRRenderer {
  static func createUpscaler(
    device: MTLDevice,
    argumentContainer: ArgumentContainer
  ) -> MTLFXTemporalScaler {
    let desc = MTLFXTemporalScalerDescriptor()
    desc.inputWidth = argumentContainer.rayTracedTextureSize
    desc.inputHeight = argumentContainer.rayTracedTextureSize
    desc.outputWidth = argumentContainer.renderTargetSize
    desc.outputHeight = argumentContainer.renderTargetSize
    
    desc.colorTextureFormat = .rgb10a2Unorm
    desc.depthTextureFormat = .r32Float
    desc.motionTextureFormat = .rg16Float
    desc.outputTextureFormat = .rgb10a2Unorm
    
    desc.isAutoExposureEnabled = false
    desc.isInputContentPropertiesEnabled = false
    desc.inputContentMinScale = 3
    desc.inputContentMaxScale = 3
    
    let upscaler = desc.makeTemporalScaler(device: device)
    guard let upscaler else {
      fatalError("The temporal scaler effect is not usable!")
    }
    
    // We already store motion vectors in units of pixels. The default value
    // multiplies the vector by 'intermediateSize', which we don't want.
    upscaler.motionVectorScaleX = 1
    upscaler.motionVectorScaleY = 1
    upscaler.isDepthReversed = true
    
    return upscaler
  }
  
  func updateUpscaler() {
    // Reset the upscaler.
    let resetUpscaler = argumentContainer.resetUpscaler
    upscaler.reset = resetUpscaler
    
    // Bind the intermediate textures.
    let textureIndex = argumentContainer.doubleBufferIndex()
    let textures = bufferedIntermediateTextures[textureIndex]
    upscaler.colorTexture = textures.color
    upscaler.depthTexture = textures.depth
    upscaler.motionTexture = textures.motion
    upscaler.outputTexture = textures.upscaled
    
    // Assign the jitter offsets.
    let jitterOffsets = argumentContainer.createJitterOffsets()
    upscaler.jitterOffsetX = -jitterOffsets.x
    upscaler.jitterOffsetY = -jitterOffsets.y
  }
  
  func dispatchUpscalingWork() {
    // Run the upscaling.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    updateUpscaler()
    upscaler.encode(commandBuffer: commandBuffer)
    commandBuffer.commit()
  }
}
