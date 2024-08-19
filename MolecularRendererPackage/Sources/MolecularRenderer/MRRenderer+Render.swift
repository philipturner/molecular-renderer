//
//  MRRenderer+Render.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Metal
import MetalFX
import class QuartzCore.CAMetalLayer

// MARK: - Public API

extension MRRenderer {
  public func render(
    layer: CAMetalLayer,
    handler: @escaping () -> Void
  ) {
    var commandBuffer = self.render()
    commandBuffer.commit()
    commandBuffer = commandQueue.makeCommandBuffer()!
    
    // Acquire a reference to the drawable.
    let drawable = layer.nextDrawable()!
    let upscaledSize = intermediateTextureSize * upscaleFactor
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

// MARK: - Metal Command Encoding

extension MRRenderer {
  private func upscale(
    commandBuffer: MTLCommandBuffer,
    drawableTexture: MTLTexture
  ) {
    resetTracker.update(time: time)
    
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
  
  private func render() -> MTLCommandBuffer {
    self.updateResources()
    
    // TODO: Working on decoupling the BVH construction from the render pass.
    var commandBuffer = commandQueue.makeCommandBuffer()!
    var encoder = commandBuffer.makeComputeCommandEncoder()!
    bvhBuilder.buildDenseGrid(encoder: encoder)
    encoder.endEncoding()
    
    let frameID = bvhBuilder.frameReportCounter
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let executionTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
      self.bvhBuilder.frameReportQueue.sync {
        for index in self.bvhBuilder.frameReports.indices.reversed() {
          guard self.bvhBuilder.frameReports[index].frameID == frameID else {
            continue
          }
          self.bvhBuilder.frameReports[index].geometryTime = executionTime
          break
        }
      }
    }
    
    commandBuffer.commit()
    commandBuffer = commandQueue.makeCommandBuffer()!
    
    encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(renderPipeline)
    bvhBuilder.encodeGridArguments(encoder: encoder)
    bvhBuilder.setGridWidth(arguments: &currentArguments!)
    
    // Encode the arguments.
    let tempAllocation = malloc(256)!
    if previousArguments == nil {
      previousArguments = currentArguments
    }
    let stride = MemoryLayout<Arguments>.stride
    precondition(stride <= 128)
    memcpy(tempAllocation, &currentArguments!, stride)
    memcpy(tempAllocation + 128, &previousArguments!, stride)
    encoder.setBytes(tempAllocation, length: 256, index: 0)
    free(tempAllocation)
    
    bvhBuilder.atomStyles.withUnsafeBufferPointer {
      let length = $0.count * MemoryLayout<MRAtomStyle>.stride
      encoder.setBytes($0.baseAddress!, length: length, index: 1)
    }
    
    // Encode the lights.
    let lightsBufferOffset = renderIndex * (lightsBuffer.length / 3)
    let lightsRawPointer = lightsBuffer.contents() + lightsBufferOffset
    let lightsPointer = lightsRawPointer.assumingMemoryBound(to: MRLight.self)
    for i in 0..<lights.count {
      lightsPointer[i] = lights[i]
    }
    encoder.setBuffer(lightsBuffer, offset: lightsBufferOffset, index: 2)
    
    // Encode the output textures.
    let textures = self.bufferedIntermediateTextures[jitterFrameID % 2]
    encoder.setTextures(
      [textures.color, textures.depth, textures.motion], range: 0..<3)
    
    // Dispatch an even number of threads (the shader will rearrange them).
    let numThreadgroupsX = (intermediateTextureSize + 7) / 8
    let numThreadgroupsY = (intermediateTextureSize + 7) / 8
    encoder.dispatchThreadgroups(
      MTLSizeMake(numThreadgroupsX, numThreadgroupsY, 1),
      threadsPerThreadgroup: MTLSizeMake(8, 8, 1))
    encoder.endEncoding()
    
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let executionTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
      self.bvhBuilder.frameReportQueue.sync {
        for index in self.bvhBuilder.frameReports.indices.reversed() {
          guard self.bvhBuilder.frameReports[index].frameID == frameID else {
            continue
          }
          self.bvhBuilder.frameReports[index].renderTime = executionTime
          break
        }
      }
    }
    
    return commandBuffer
  }
}

