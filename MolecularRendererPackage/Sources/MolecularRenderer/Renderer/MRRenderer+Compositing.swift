//
//  MRRenderer+Compositing.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/9/24.
//

import Metal
import protocol QuartzCore.CAMetalDrawable

extension MRRenderer {
  func dispatchCompositingWork(texture: MTLTexture) {
    let renderTargetSize = argumentContainer.renderTargetSize
    guard texture.width == renderTargetSize,
          texture.height == renderTargetSize else {
      fatalError("Drawable texture had incorrect dimensions.")
    }
    
    // Run the upscaling.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    
    // Copy the upscaled texture to the drawable.
    let textureIndex = argumentContainer.doubleBufferIndex()
    let textures = bufferedIntermediateTextures[textureIndex]
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    blitEncoder.copy(from: textures.upscaled, to: texture)
    blitEncoder.endEncoding()
    
    commandBuffer.commit()
  }
}
