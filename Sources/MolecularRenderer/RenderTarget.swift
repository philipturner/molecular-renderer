//
//  RenderTarget.swift
//  molecular-renderer
//
//  Created by Philip Turner on 9/14/25.
//

/*
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
   desc.width = argumentContainer.upscaledSize
   desc.height = argumentContainer.upscaledSize
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
 */
