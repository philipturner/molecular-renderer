//
//  MRRenderer+Rendering.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Metal

extension MRRenderer {
  func initRayTracer(library: MTLLibrary) {
    let constants = MTLFunctionConstantValues()
    var screenWidth = UInt32(argumentContainer.intermediateTextureSize)
    var screenHeight = UInt32(argumentContainer.intermediateTextureSize)
    constants.setConstantValue(&screenWidth, type: .uint, index: 0)
    constants.setConstantValue(&screenHeight, type: .uint, index: 1)
    
    let function = try! library.makeFunction(
      name: "renderAtoms", constantValues: constants)
    
    let desc = MTLComputePipelineDescriptor()
    desc.computeFunction = function
    desc.maxTotalThreadsPerThreadgroup = 1024
    self.renderPipeline = try! device.makeComputePipelineState(
      descriptor: desc, options: [], reflection: nil)
  }
  
  func dispatchRenderingWork(frameID: Int) {
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    
    do {
      let cameraArguments = argumentContainer.createCameraArguments()
      let renderArguments = [argumentContainer.createRenderArguments()]
      
      func setBytes<T>(_ array: [T], index: Int) {
        let elementLength = MemoryLayout<T>.stride
        let arrayLength = array.count * elementLength
        encoder.setBytes(array, length: arrayLength, index: index)
      }
      setBytes(cameraArguments, index: 0)
      setBytes(renderArguments, index: 1)
    }
    
    encoder.setBuffer(bvhBuilder.bvhArguments, offset: 0, index: 2)
    encoder.setBuffer(bvhBuilder.smallCellOffsets, offset: 0, index: 3)
    encoder.setBuffer(bvhBuilder.smallAtomReferences, offset: 0, index: 4)
    encoder.setBuffer(bvhBuilder.convertedAtoms, offset: 0, index: 5)
    encoder.setBuffer(bvhBuilder.atomMotionVectors, offset: 0, index: 6)
    
    do {
      let elementColors = argumentContainer.elementColors
      let byteCount = elementColors.count * 16
      encoder.setBytes(elementColors, length: byteCount, index: 7)
    }
    
    // Textures 0 - 2
    do {
      let textureIndex = argumentContainer.doubleBufferIndex()
      let textures = bufferedIntermediateTextures[textureIndex]
      encoder.setTexture(textures.color, index: 0)
      encoder.setTexture(textures.depth, index: 1)
      encoder.setTexture(textures.motion, index: 2)
    }
    
    // Dispatch
    do {
      let pipeline = renderPipeline!
      encoder.setComputePipelineState(pipeline)
      
      // Dispatch an even number of threads (the shader will rearrange them).
      var dispatchWidth = argumentContainer.intermediateTextureSize
      dispatchWidth = (dispatchWidth + 7) / 8
      encoder.dispatchThreadgroups(
        MTLSize(width: dispatchWidth, height: dispatchWidth, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    }
    
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
