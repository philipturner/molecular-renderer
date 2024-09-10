//
//  MRRenderer+Compositing.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/9/24.
//

import Metal
import protocol QuartzCore.CAMetalDrawable

extension MRRenderer {
  static func createCompositePipeline(
    library: MTLLibrary
  ) -> MTLComputePipelineState {
    let function = library.makeFunction(name: "compositeFinalImage")
    guard let function else {
      fatalError("Could not create function.")
    }
    let device = library.device
    return try! device.makeComputePipelineState(function: function)
  }
  
  func dispatchCompositingWork(drawable: CAMetalDrawable) {
    let renderTargetSize = argumentContainer.renderTargetSize
    guard drawable.texture.width == renderTargetSize,
          drawable.texture.height == renderTargetSize else {
      fatalError("Drawable texture had incorrect dimensions.")
    }
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    
    let textureIndex = argumentContainer.doubleBufferIndex()
    let textures = bufferedIntermediateTextures[textureIndex]
    encoder.setTexture(textures.upscaled, index: 0)
    encoder.setTexture(drawable.texture, index: 1)
    
    // Dispatch
    do {
      let pipeline = compositePipeline
      encoder.setComputePipelineState(pipeline)
      
      let dispatchSize = argumentContainer.renderTargetSize
      encoder.dispatchThreads(
        MTLSize(width: dispatchSize, height: dispatchSize, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    }
    
    encoder.endEncoding()
    commandBuffer.commit()
  }
}
