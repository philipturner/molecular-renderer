//
//  BVHBuilder+BuildSmall.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/27/23.
//

import Metal

struct BVHBuildSmallPipelines {
  var buildSmallPart1: MTLComputePipelineState
  var buildSmallPart2: MTLComputePipelineState
  var buildSmallPart3: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    buildSmallPart1 = createPipeline(name: "buildSmallPart1")
    buildSmallPart2 = createPipeline(name: "buildSmallPart2")
    buildSmallPart3 = createPipeline(name: "buildSmallPart3")
  }
}

extension BVHBuilder {
  func buildSmallBVH(frameID: Int) {
    let atoms = renderer.argumentContainer.currentAtoms
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    setAllocationCounter(encoder: encoder)
    clearSmallCellMetadata(encoder: encoder)
    
    buildSmallPart1(encoder: encoder)
    buildSmallPart2(encoder: encoder)
    buildSmallPart3(encoder: encoder)
    encoder.endEncoding()
    
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let frameReporter = self.renderer.frameReporter!
      frameReporter.queue.sync {
        let index = frameReporter.index(of: frameID)
        guard let index else {
          return
        }
        
        let executionTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        frameReporter.reports[index].buildSmallTime = executionTime
      }
    }
    commandBuffer.commit()
  }
}

extension BVHBuilder {
  func setAllocationCounter(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 0)
    
    // Argument 1
    var pattern: UInt32 = .zero
    encoder.setBytes(&pattern, length: 4, index: 1)
    
    // Dispatch
    let pipeline = resetMemoryPipelines.resetMemory1D
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(8, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  func clearSmallCellMetadata(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 0)
    
    // Argument 1
    var pattern: UInt32 = .zero
    encoder.setBytes(&pattern, length: 4, index: 1)
    
    // Dispatch
    let pipeline = resetMemoryPipelines.resetMemory1D
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: smallCellDispatchArguments128x1x1,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
}

extension BVHBuilder {
  func buildSmallPart1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 0)
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 1)
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 2)
    
    // Dispatch
    let atoms = renderer.argumentContainer.currentAtoms
    let pipeline = buildSmallPipelines.buildSmallPart1
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  func buildSmallPart2(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 0)
    encoder.setBuffer(smallCellCounters, offset: 0, index: 1)
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 2)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart2
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: smallCellDispatchArguments128x1x1,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  func buildSmallPart3(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 3
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 0)
    encoder.setBuffer(smallCellCounters, offset: 0, index: 1)
    encoder.setBuffer(smallCellAtomReferences, offset: 0, index: 2)
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 3)
    
    // Dispatch
    let atoms = renderer.argumentContainer.currentAtoms
    let pipeline = buildSmallPipelines.buildSmallPart3
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
}
