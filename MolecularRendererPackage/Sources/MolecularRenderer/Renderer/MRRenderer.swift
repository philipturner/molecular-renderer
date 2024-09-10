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
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var renderPipeline: MTLComputePipelineState
  var upscaler: MTLFXTemporalScaler
  var compositePipeline: MTLComputePipelineState
  
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
    guard let elementColors = descriptor.elementColors,
          let elementRadii = descriptor.elementRadii,
          let library = descriptor.library,
          let renderTargetSize = descriptor.renderTargetSize else {
      fatalError("Descriptor was incomplete.")
    }
    argumentContainer.elementColors = ArgumentContainer
      .createElementColors(elementColors)
    argumentContainer.elementRadii = ArgumentContainer
      .createElementRadii(elementRadii)
    
    guard renderTargetSize % 6 == 0 else {
      fatalError("Render target dimensions must be divisible by 6.")
    }
    argumentContainer.renderTargetSize = renderTargetSize
    
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
      
      desc.width = argumentContainer.rayTracedTextureSize
      desc.height = argumentContainer.rayTracedTextureSize
      desc.pixelFormat = .rgb10a2Unorm
      let color = device.makeTexture(descriptor: desc)!
      
      desc.pixelFormat = .r32Float
      let depth = device.makeTexture(descriptor: desc)!
      
      desc.pixelFormat = .rg16Float
      let motion = device.makeTexture(descriptor: desc)!
      
      desc.pixelFormat = .rgb10a2Unorm
      desc.width = argumentContainer.renderTargetSize
      desc.height = argumentContainer.renderTargetSize
      let upscaled = device.makeTexture(descriptor: desc)!
      
      let textures = IntermediateTextures(
        color: color, depth: depth, motion: motion, upscaled: upscaled)
      bufferedIntermediateTextures.append(textures)
      
      for texture in [color, depth, motion, upscaled] {
        encoder.optimizeContentsForGPUAccess(texture: texture)
      }
    }
    encoder.endEncoding()
    commandBuffer.commit()
    
    renderPipeline = Self.createRenderPipeline(library: library)
    upscaler = Self.createUpscaler(
      device: device, argumentContainer: argumentContainer)
    compositePipeline = Self.createCompositePipeline(library: library)
    
    bvhBuilder = BVHBuilder(renderer: self, library: library)
    frameReporter = FrameReporter()
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
    
    // Encode the geometry, render, and upscaling passes.
    bvhBuilder.buildLargeBVH(frameID: frameID)
    bvhBuilder.buildSmallBVH(frameID: frameID)
    dispatchRenderingWork(frameID: frameID)
    dispatchUpscalingWork()
    
    // Encode the compositing pass.
    let drawable = layer.nextDrawable()!
    dispatchCompositingWork(drawable: drawable)
    
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
