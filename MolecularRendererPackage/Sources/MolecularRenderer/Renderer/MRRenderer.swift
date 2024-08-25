//
//  MRRenderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/17/23.
//

import Metal
import MetalFX
import class QuartzCore.CAMetalLayer

public class MRRenderer {
  // State variables.
  var argumentContainer: ArgumentContainer = .init()
  var textureIndex: Int = 0
  
  // Properties that track the frame ID.
  var renderIndex: Int = 0
  var resetTracker: ResetTracker = .init()
  
  // Objects that supply data to the renderer.
  var atomProvider: MRAtomProvider!
  var atomColors: [SIMD3<Float>] = []
  var atomRadii: [Float] = []
  var time: MRTime!
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var bvhBuilder: BVHBuilder!
  var upscaler: MTLFXTemporalScaler!
  var renderPipeline: MTLComputePipelineState!
  
  struct IntermediateTextures {
    var color: MTLTexture
    var depth: MTLTexture
    var motion: MTLTexture
    
    // Metal is forcing me to make another texture for this, because the
    // drawable texture "must have private storage mode".
    var upscaled: MTLTexture
  }
  
  // Double-buffer the textures to remove dependencies between frames.
  var bufferedIntermediateTextures: [IntermediateTextures] = []
  
  // Enter the width and height of the texture to present, not the resolution
  // you expect the internal GPU shader to write to.
  public init(descriptor: MRRendererDescriptor) {
    guard let url = descriptor.url,
          let intermediateTextureSize = descriptor.intermediateTextureSize,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    argumentContainer.intermediateTextureSize = intermediateTextureSize
    argumentContainer.upscaleFactor = upscaleFactor
    
    // Initialize Metal resources.
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!
    
    // Ensure the textures use lossless compression.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeBlitCommandEncoder()!
    
    // Initialize each texture twice, establishing a double buffer.
    for _ in 0..<2 {
      let desc = MTLTextureDescriptor()
      desc.storageMode = .private
      desc.usage = [ .shaderWrite, .shaderRead ]
      
      desc.width = argumentContainer.intermediateTextureSize
      desc.height = argumentContainer.intermediateTextureSize
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
      desc.width = argumentContainer.upscaledTextureSize
      desc.height = argumentContainer.upscaledTextureSize
      let upscaled = device.makeTexture(descriptor: desc)!
      upscaled.label = "Upscaled Color"
      
      let textures = IntermediateTextures(
        color: color, depth: depth, motion: motion, upscaled: upscaled)
      bufferedIntermediateTextures.append(textures)
      
      for texture in [color, depth, motion, upscaled] {
        encoder.optimizeContentsForGPUAccess(texture: texture)
      }
    }
    encoder.endEncoding()
    commandBuffer.commit()
    
    let library = try! device.makeLibrary(URL: descriptor.url!)
    self.bvhBuilder = BVHBuilder(renderer: self, library: library)
    bvhBuilder.reportPerformance = descriptor.reportPerformance
    
    initUpscaler()
    initRayTracer(library: library)
  }
  
  public func render(
    layer: CAMetalLayer,
    handler: @escaping () -> Void
  ) {
    updateResources()
    
    let frameID = bvhBuilder.frameReportCounter
    bvhBuilder.preprocessAtoms(
      commandQueue: commandQueue, frameID: frameID)
    bvhBuilder.buildDenseGrid(
      commandQueue: commandQueue, frameID: frameID)
    render(
      commandQueue: commandQueue, frameID: frameID)
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    
    // Acquire a reference to the drawable.
    let drawable = layer.nextDrawable()!
    let upscaledSize = argumentContainer.upscaledTextureSize
    guard drawable.texture.width == upscaledSize &&
            drawable.texture.height == upscaledSize else {
      fatalError("Drawable texture had incorrect dimensions.")
    }
    
    // Encode the upscaling pass.
    upscale(commandBuffer: commandBuffer, drawableTexture: drawable.texture)
    
    // Present the drawable and signal the semaphore.
    commandBuffer.present(drawable)
    commandBuffer.addCompletedHandler { _ in
      handler()
    }
    commandBuffer.commit()
  }
}
