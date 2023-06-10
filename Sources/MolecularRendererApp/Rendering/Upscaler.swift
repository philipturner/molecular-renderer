//
//  Upscaler.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/21/23.
//

import Metal
import MetalFX

// Partially sourced from:
// https://developer.apple.com/documentation/metalfx/applying_temporal_antialiasing_and_upscaling_using_metalfx

struct Upscaler {
  var intermediateSize: Int
  var upscaledSize: Int
  var jitterFrameID: Int = 0
  var jitterOffsets: SIMD2<Float> = .zero
  var textureIndex: Int = 0
  var resetScaler = true
  static let doingUpscaling = true
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var upscaler: MTLFXTemporalScaler?
  
  struct IntermediateTextures {
    var color: MTLTexture
    var depth: MTLTexture
    var motion: MTLTexture
    
    // Metal is forcing me to make another texture for this, because the
    // drawable texture "must have private storage mode".
    var upscaled: MTLTexture
  }
  
  // Double-buffer the textures to remove dependencies between frames.
  var textures: [IntermediateTextures] = []
  var currentTextures: IntermediateTextures {
    self.textures[jitterFrameID % 2]
  }
  
  init(renderer: Renderer) {
    self.device = renderer.device
    self.commandQueue = renderer.commandQueue
    
    self.intermediateSize = Int(ContentView.size / 2)
    self.upscaledSize = Int(ContentView.size)
    
    guard Upscaler.doingUpscaling else {
      // Do not create the upscaler object or intermediate textures.
      return
    }
    
    // Ensure the textures use lossless compression.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeBlitCommandEncoder()!
    
    for _ in 0..<2 {
      let desc = MTLTextureDescriptor()
      desc.width = intermediateSize
      desc.height = intermediateSize
      desc.storageMode = .private
      desc.usage = [ .shaderWrite, .shaderRead ]
      
      desc.pixelFormat = .rgb10a2Unorm
      let color = device.makeTexture(descriptor: desc)!
      color.label = "Intermediate Color"
      
      desc.pixelFormat = .r32Float
      let depth = device.makeTexture(descriptor: desc)!
      depth.label = "Intermediate Depth"
      
      desc.pixelFormat = .rg16Float
      let motion = device.makeTexture(descriptor: desc)!
      motion.label = "Intermediate Motion"
      
      desc.pixelFormat = .rgb10a2Unorm
      desc.width = upscaledSize
      desc.height = upscaledSize
      let upscaled = device.makeTexture(descriptor: desc)!
      upscaled.label = "Upscaled Color"
      
      textures.append(IntermediateTextures(
        color: color, depth: depth, motion: motion, upscaled: upscaled))
      
      for texture in [color, depth, motion, upscaled] {
        encoder.optimizeContentsForGPUAccess(texture: texture)
      }
    }
    
    encoder.endEncoding()
    commandBuffer.commit()
    
    let desc = MTLFXTemporalScalerDescriptor()
    desc.inputWidth = intermediateSize
    desc.inputHeight = intermediateSize
    desc.outputWidth = upscaledSize
    desc.outputHeight = upscaledSize
    desc.colorTextureFormat = textures[0].color.pixelFormat
    desc.depthTextureFormat = textures[0].depth.pixelFormat
    desc.motionTextureFormat = textures[0].motion.pixelFormat
    desc.outputTextureFormat = desc.colorTextureFormat
    
    desc.isAutoExposureEnabled = false
    desc.isInputContentPropertiesEnabled = false
    desc.inputContentMinScale = 2.0
    desc.inputContentMaxScale = 2.0
    
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
}

extension Upscaler {
  mutating func updateResources() {
    self.jitterFrameID += 1
    self.jitterOffsets = makeJitterOffsets()
    self.textureIndex = (self.textureIndex + 1) % 2
  }
  
  private func makeJitterOffsets() -> SIMD2<Float> {
    if Upscaler.doingUpscaling == false {
      return SIMD2.zero
    }
    
    func halton(index: UInt32, base: UInt32) -> Float {
      var result: Float = 0.0
      var fractional: Float = 1.0
      var currentIndex: UInt32 = index
      while currentIndex > 0 {
        fractional /= Float(base)
        result += fractional * Float(currentIndex % base)
        currentIndex /= base
      }
      return result
    }
    
    // The sample uses a Halton sequence rather than purely random numbers to
    // generate the sample positions to ensure good pixel coverage. This has the
    // result of sampling a different point within each pixel every frame.
    let jitterIndex = UInt32(self.jitterFrameID % 32 + 1)
    
    // Return Halton samples (+/- 0.5, +/- 0.5) that represent offsets of up to
    // half a pixel.
    let x = halton(index: jitterIndex, base: 2) - 0.5
    let y = halton(index: jitterIndex, base: 3) - 0.5
    
    // We're not sampling textures or working with multiple coordinate spaces.
    // No need to flip the Y coordinate to match another coordinate space.
    return SIMD2(x, y)
  }
  
  mutating func upscale(
    commandBuffer: MTLCommandBuffer,
    drawableTexture: MTLTexture
  ) {
    guard let upscaler else {
      fatalError("Upscaling is disabled.")
    }
    
    // If the frame has just begun, the upscaler needs to recognize that a
    // history of samples doesn't exist yet.
    upscaler.reset = self.resetScaler
    self.resetScaler = false
    
    // Bind the intermediate textures.
    let currentTextures = self.currentTextures
    upscaler.colorTexture = currentTextures.color
    upscaler.depthTexture = currentTextures.depth
    upscaler.motionTexture = currentTextures.motion
    upscaler.outputTexture = currentTextures.upscaled
    upscaler.jitterOffsetX = -self.jitterOffsets.x
    upscaler.jitterOffsetY = -self.jitterOffsets.y
    upscaler.encode(commandBuffer: commandBuffer)
    
    // Metal is forcing me to copy the upscaled texture to the drawable.
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    blitEncoder.copy(from: currentTextures.upscaled, to: drawableTexture)
//    blitEncoder.copy(from: currentTextures.color, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOriginMake(0, 0, 0), sourceSize: MTLSizeMake(768, 768, 1), to: drawableTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOriginMake(0, 0, 0))
    blitEncoder.endEncoding()
  }
}
