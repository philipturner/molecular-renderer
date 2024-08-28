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
  var argumentContainer: ArgumentContainer = .init()
  var bvhBuilder: BVHBuilder!
  var frameReporter: FrameReporter!
  
  // Objects that supply data to the renderer.
  var atomProvider: MRAtomProvider!
  var atomColors: [SIMD3<Float>] = []
  var atomRadii: [Float] = []
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var renderPipeline: MTLComputePipelineState!
  var upscaler: MTLFXTemporalScaler!
  
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
    guard let intermediateTextureSize = descriptor.intermediateTextureSize,
          let library = descriptor.library,
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
    
    bvhBuilder = BVHBuilder(renderer: self, library: library)
    frameReporter = FrameReporter()
    
    initUpscaler()
    initRayTracer(library: library)
  }
  
  public func render(
    layer: CAMetalLayer,
    handler: @escaping () -> Void
  ) {
    let frameID = argumentContainer.frameID
    frameReporter.registerFrameChange(frameID: frameID)
    frameReporter.log()
    
    // Fetch the atoms for the current frame.
    argumentContainer.updateAtoms(provider: atomProvider)
    
    // Encode the work.
    bvhBuilder.prepareBVH(frameID: frameID)
    bvhBuilder.buildLargeBVH(frameID: frameID)
//    bvhBuilder.buildSmallBVH(frameID: frameID)
//    dispatchRenderingWork(frameID: frameID)
    
    // Dispatch the upscaling work.
    let drawable = layer.nextDrawable()!
//    dispatchUpscalingWork(texture: drawable.texture)
    
    // Perform synchronization in an empty command buffer.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    commandBuffer.present(drawable)
    commandBuffer.addCompletedHandler { _ in
      handler()
    }
    commandBuffer.commit()
    
    // Clear the state, setting the stage for the next frame.
    argumentContainer.registerCompletedFrame()
  }
}
