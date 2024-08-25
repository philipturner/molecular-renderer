//
//  MRRenderer+Upscaling.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

import Metal
import MetalFX
import protocol QuartzCore.CAMetalDrawable

// Track when to reset the MetalFX upscaler.
struct ResetTracker {
  var currentFrameID: Int = -1
  var resetUpscaler: Bool = false
  
  mutating func update(time: MRTime) {
    let nextFrameID = time.absolute.frames
    if nextFrameID == 0 && nextFrameID != currentFrameID {
      resetUpscaler = true
    } else {
      resetUpscaler = false
    }
    currentFrameID = nextFrameID
  }
}

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
  
  func checkUpscaledSize(drawable: CAMetalDrawable) {
    let upscaledSize = argumentContainer.upscaledTextureSize
    guard drawable.texture.width == upscaledSize &&
            drawable.texture.height == upscaledSize else {
      fatalError("Drawable texture had incorrect dimensions.")
    }
  }
  
  func updateResetTracker() {
    guard let time = argumentContainer.time else {
      fatalError("Time was not specified.")
    }
    resetTracker.update(time: time)
  }
  
  func updateUpscaler(reset: Bool) {
    // Bind the intermediate textures.
    let textureIndex = argumentContainer.doubleBufferIndex()
    let textures = bufferedIntermediateTextures[textureIndex]
    upscaler.reset = reset
    upscaler.colorTexture = textures.color
    upscaler.depthTexture = textures.depth
    upscaler.motionTexture = textures.motion
    upscaler.outputTexture = textures.upscaled
    
    // Assign the jitter offsets.
    let jitterOffsets = argumentContainer.createJitterOffsets()
    upscaler.jitterOffsetX = -jitterOffsets.x
    upscaler.jitterOffsetY = -jitterOffsets.y
  }
  
  func upscale(
    commandQueue: MTLCommandQueue,
    drawable: CAMetalDrawable
  ) {
    checkUpscaledSize(drawable: drawable)
    updateResetTracker()
    updateUpscaler(reset: resetTracker.resetUpscaler)
    
    // Start a command buffer.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    upscaler.encode(commandBuffer: commandBuffer)
    
    // Start a blit encoder.
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    
    // Bind the upscaled texture.
    let textureIndex = argumentContainer.doubleBufferIndex()
    let textures = bufferedIntermediateTextures[textureIndex]
    blitEncoder.copy(from: textures.upscaled, to: drawable.texture)
    
    // Finish the blit encoder.
    blitEncoder.endEncoding()
    
    // Finish the command buffer.
    commandBuffer.commit()
  }
}
