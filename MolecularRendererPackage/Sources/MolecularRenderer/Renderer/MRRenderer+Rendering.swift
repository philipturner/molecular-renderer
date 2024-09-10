//
//  MRRenderer+Rendering.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Metal

extension MRRenderer {
  static func createRenderPipeline(
    library: MTLLibrary
  ) -> MTLComputePipelineState {
    let function = library.makeFunction(name: "renderAtoms")
    guard let function else {
      fatalError("Could not create function.")
    }
    
    let desc = MTLComputePipelineDescriptor()
    desc.computeFunction = function
    desc.maxTotalThreadsPerThreadgroup = 1024
    
    let device = library.device
    return try! device.makeComputePipelineState(
      descriptor: desc, options: [], reflection: nil)
  }
  
  func dispatchRenderingWork(frameID: Int) {
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    
    // Bind the camera arguments.
    do {
      let cameraArguments = argumentContainer.createCameraArguments()
      let elementLength = MemoryLayout<CameraArguments>.stride
      let arrayLength = 2 * elementLength
      encoder.setBytes(cameraArguments, length: arrayLength, index: 0)
    }
    
    // Bind the render arguments.
    do {
      var renderArguments = argumentContainer.createRenderArguments()
      let length = MemoryLayout<RenderArguments>.stride
      encoder.setBytes(&renderArguments, length: length, index: 1)
    }
    
    // Bind the bounding box.
    do {
      encoder.setBuffer(bvhBuilder.globalCounters, offset: 128, index: 2)
    }
    
    // Bind the element colors.
    do {
      let elementColors = argumentContainer.elementColors
      let byteCount = elementColors.count * 8
      encoder.setBytes(elementColors, length: byteCount, index: 3)
    }
    
    // Bind the per-atom buffers.
    do {
      let currentIndex = argumentContainer.tripleBufferIndex()
      let currentAtoms = bvhBuilder.originalAtoms[currentIndex]
      encoder.setBuffer(currentAtoms, offset: 0, index: 4)
      encoder.setBuffer(bvhBuilder.atomMetadata, offset: 0, index: 5)
      encoder.setBuffer(bvhBuilder.convertedAtoms, offset: 0, index: 6)
      encoder.setBuffer(bvhBuilder.largeAtomReferences, offset: 0, index: 7)
      encoder.setBuffer(bvhBuilder.smallAtomReferences, offset: 0, index: 8)
    }
    
    // Bind the per-cell buffers.
    do {
      encoder.setBuffer(bvhBuilder.cellGroupMarks, offset: 0, index: 9)
      encoder.setBuffer(bvhBuilder.largeCellOffsets, offset: 0, index: 10)
      encoder.setBuffer(
        bvhBuilder.compactedLargeCellMetadata, offset: 0, index: 11)
      encoder.setBuffer(
        bvhBuilder.compactedSmallCellMetadata, offset: 0, index: 12)
    }
    
    // Bind the textures.
    do {
      let textureIndex = argumentContainer.doubleBufferIndex()
      let textures = bufferedIntermediateTextures[textureIndex]
      encoder.setTexture(textures.color, index: 0)
      encoder.setTexture(textures.depth, index: 1)
      encoder.setTexture(textures.motion, index: 2)
    }
    
    // Allocate threadgroup memory.
    do {
      let byteCount = 64 * 8 * 8
      encoder.setThreadgroupMemoryLength(byteCount, index: 0)
    }
    
    // Dispatch
    do {
      let pipeline = renderPipeline
      encoder.setComputePipelineState(pipeline)
      
      let dispatchSize = (argumentContainer.rayTracedTextureSize + 7) / 8
      encoder.dispatchThreadgroups(
        MTLSize(width: dispatchSize, height: dispatchSize, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    }
    
    // Submit the command buffer.
    encoder.endEncoding()
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let frameReporter = self.frameReporter!
      frameReporter.queue.sync {
        let index = frameReporter.index(of: frameID)
        guard let index else {
          return
        }
        
        let executionTime =
        commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        frameReporter.reports[index].renderTime = executionTime
      }
    }
    commandBuffer.commit()
  }
}
