//
//  MRRenderer+Upscaling.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

import Metal
import MetalFX
import protocol QuartzCore.CAMetalDrawable

extension MRRenderer {
  func initUpscaler() {
    let desc = MTLFXTemporalScalerDescriptor()
    desc.inputWidth = argumentContainer.intermediateTextureSize
    desc.inputHeight = argumentContainer.intermediateTextureSize
    desc.outputWidth = argumentContainer.upscaledTextureSize
    desc.outputHeight = argumentContainer.upscaledTextureSize
    
    let textures = bufferedIntermediateTextures[0]
    desc.colorTextureFormat = textures.color.pixelFormat
    desc.depthTextureFormat = textures.depth.pixelFormat
    desc.motionTextureFormat = textures.motion.pixelFormat
    desc.outputTextureFormat = desc.colorTextureFormat
    
    desc.isAutoExposureEnabled = false
    desc.isInputContentPropertiesEnabled = false
    desc.inputContentMinScale = Float(argumentContainer.upscaleFactor)
    desc.inputContentMaxScale = Float(argumentContainer.upscaleFactor)
    
    guard let upscaler = desc.makeTemporalScaler(device: device) else {
      fatalError("The temporal scaler effect is not usable!")
    }
    
    self.upscaler = upscaler
    
    // We already store motion vectors in units of pixels. The default value
    // multiplies the vector by 'intermediateSize', which we don't want.
    upscaler.motionVectorScaleX = 1
    upscaler.motionVectorScaleY = 1
    upscaler.isDepthReversed = true
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
  
  func dispatchUpscalingWork(texture: MTLTexture) {
    let upscaledSize = argumentContainer.upscaledTextureSize
    guard texture.width == upscaledSize,
          texture.height == upscaledSize else {
      fatalError("Drawable texture had incorrect dimensions.")
    }
    
    // Run the upscaling.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    updateUpscaler()
    upscaler.encode(commandBuffer: commandBuffer)
    
    // Copy the upscaled texture to the drawable.
    let textureIndex = argumentContainer.doubleBufferIndex()
    let textures = bufferedIntermediateTextures[textureIndex]
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    blitEncoder.copy(from: textures.upscaled, to: texture)
    blitEncoder.endEncoding()
    
    commandBuffer.commit()
  }
}
