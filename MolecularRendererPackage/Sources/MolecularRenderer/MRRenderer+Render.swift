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
    guard let upscaler else {
      fatalError("Attempted to upscale in offline mode.")
    }
    resetTracker.update(time: time)
    
    // Bind the intermediate textures.
    let currentTextures = self.currentTextures
    upscaler.reset = resetTracker.resetUpscaler
    upscaler.colorTexture = currentTextures.color
    upscaler.depthTexture = currentTextures.depth
    upscaler.motionTexture = currentTextures.motion
    upscaler.outputTexture = currentTextures.upscaled
    upscaler.jitterOffsetX = -self.jitterOffsets.x
    upscaler.jitterOffsetY = -self.jitterOffsets.y
    upscaler.encode(commandBuffer: commandBuffer)
    
    // Metal is forcing me to copy the upscaled texture to the drawable.
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    blitEncoder.copy(from: currentTextures.upscaled!, to: drawableTexture)
    blitEncoder.endEncoding()
  }
  
  private func render() -> MTLCommandBuffer {
    self.updateResources()
    
    var commandBuffer = commandQueue.makeCommandBuffer()!
    var encoder = commandBuffer.makeComputeCommandEncoder()!
    accelBuilder.buildDenseGrid(encoder: encoder)
    encoder.endEncoding()
    
    let frameID = accelBuilder.frameReportCounter
    func addHandler(
      _ closure: @escaping (inout MRFrameReport, Double) -> Void
    ) {
      commandBuffer.addCompletedHandler { [self] commandBuffer in
        let executionTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        self.accelBuilder.frameReportQueue.sync {
          for index in self.accelBuilder.frameReports.indices.reversed() {
            guard self.accelBuilder.frameReports[index].frameID == frameID else {
              continue
            }
            closure(&self.accelBuilder.frameReports[index], executionTime)
            break
          }
        }
      }
    }
    
    addHandler { $0.geometryTime = $1 }
    commandBuffer.commit()
    commandBuffer = commandQueue.makeCommandBuffer()!
    
    encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(renderPipeline)
    accelBuilder.encodeGridArguments(encoder: encoder)
    accelBuilder.setGridWidth(arguments: &currentArguments!)
    
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
    
    accelBuilder.styles.withUnsafeBufferPointer {
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
    let textures = self.currentTextures
    encoder.setTextures(
      [textures.color, textures.depth!, textures.motion!], range: 0..<3)
    
    // Dispatch an even number of threads (the shader will rearrange them).
    let numThreadgroupsX = (intermediateTextureSize + 7) / 8
    let numThreadgroupsY = (intermediateTextureSize + 7) / 8
    encoder.dispatchThreadgroups(
      MTLSizeMake(numThreadgroupsX, numThreadgroupsY, 1),
      threadsPerThreadgroup: MTLSizeMake(8, 8, 1))
    encoder.endEncoding()
    
    addHandler { $0.renderTime = $1 }
    return commandBuffer
  }
}

