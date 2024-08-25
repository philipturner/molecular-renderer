//
//  MRRenderer+Upscaling.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

import Metal
import MetalFX

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
    
    // TODO: Investigate whether MetalFX wants depth to be something different.
    upscaler.isDepthReversed = true
  }
  
  func upscale(
    commandBuffer: MTLCommandBuffer,
    drawableTexture: MTLTexture
  ) {
    resetTracker.update(time: time)
    
    let jitterFrameID = argumentContainer.jitterFrameID
    let jitterOffsets = argumentContainer.createJitterOffsets()
    
    // Bind the intermediate textures.
    let textures = bufferedIntermediateTextures[jitterFrameID % 2]
    upscaler.reset = resetTracker.resetUpscaler
    upscaler.colorTexture = textures.color
    upscaler.depthTexture = textures.depth
    upscaler.motionTexture = textures.motion
    upscaler.outputTexture = textures.upscaled
    upscaler.jitterOffsetX = -jitterOffsets.x
    upscaler.jitterOffsetY = -jitterOffsets.y
    upscaler.encode(commandBuffer: commandBuffer)
    
    // Metal is forcing me to copy the upscaled texture to the drawable.
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    blitEncoder.copy(from: textures.upscaled, to: drawableTexture)
    blitEncoder.endEncoding()
  }
}
