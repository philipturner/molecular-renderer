//
//  BVHBuilder+BuildSmall.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/27/23.
//

import Metal

// Part 0
// - Kernel 0: Encode the indirect dispatch arguments.
//
// Part 1
// - Kernel 0: Reset the small counter metadata.
// - Kernel 1: Accumulate the reference count for each voxel.
//
// Part 2:
// - Kernel 1: Compact the reference offset for each voxel.
// - Kernel 2: Fill the reference list for each voxel.
struct BVHBuildSmallPipelines {
  var buildSmallPart0_0: MTLComputePipelineState
  var buildSmallPart1_1: MTLComputePipelineState
  var buildSmallPart2_1: MTLComputePipelineState
  var buildSmallPart2_2: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    buildSmallPart0_0 = createPipeline(name: "buildSmallPart0_0")
    buildSmallPart1_1 = createPipeline(name: "buildSmallPart1_1")
    buildSmallPart2_1 = createPipeline(name: "buildSmallPart2_1")
    buildSmallPart2_2 = createPipeline(name: "buildSmallPart2_2")
  }
}

extension BVHBuilder {
  func buildSmallBVH(frameID: Int) {
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    buildSmallPart0_0(encoder: encoder)
    buildSmallPart1_1(encoder: encoder)
    buildSmallPart2_1(encoder: encoder)
    buildSmallPart2_2(encoder: encoder)
    encoder.endEncoding()
    
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let frameReporter = self.renderer.frameReporter!
      frameReporter.queue.sync {
        let index = frameReporter.index(of: frameID)
        guard let index else {
          return
        }
        
        let executionTime = 
        commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        frameReporter.reports[index].buildSmallTime = executionTime
      }
    }
    commandBuffer.commit()
  }
}

// MARK: - Atoms

extension BVHBuilder {
  func buildSmallPart1_1(encoder: MTLComputeCommandEncoder) {
    encoder.setBuffer(globalCounters, offset: 0, index: 0)
    encoder.setBuffer(bvhArguments, offset: 0, index: 1)
    encoder.setBuffer(largeCellMetadata, offset: 0, index: 2)
    encoder.setBuffer(largeAtomReferences, offset: 0, index: 3)
    encoder.setBuffer(convertedAtoms, offset: 0, index: 4)
    encoder.setBuffer(smallCounterMetadata, offset: 0, index: 5)
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 6)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart1_1
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: indirectDispatchArguments,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    
  }
  
  func buildSmallPart2_2(encoder: MTLComputeCommandEncoder) {
    encoder.setBuffer(bvhArguments, offset: 0, index: 0)
    encoder.setBuffer(largeCellMetadata, offset: 0, index: 1)
    encoder.setBuffer(largeAtomReferences, offset: 0, index: 2)
    encoder.setBuffer(convertedAtoms, offset: 0, index: 3)
    encoder.setBuffer(smallCounterMetadata, offset: 0, index: 4)
    encoder.setBuffer(smallAtomReferences, offset: 0, index: 5)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart2_2
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: indirectDispatchArguments,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
  }
}

// MARK: - Cells

extension BVHBuilder {
  func buildSmallPart0_0(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    do {
      let allocatedMemory = 0
      let boundingBoxMin = 16
      let boundingBoxMax = 32
      encoder.setBuffer(globalCounters, offset: allocatedMemory, index: 0)
      encoder.setBuffer(globalCounters, offset: boundingBoxMin, index: 1)
      encoder.setBuffer(globalCounters, offset: boundingBoxMax, index: 2)
    }
    
    // Arguments 3 - 4
    encoder.setBuffer(bvhArguments, offset: 0, index: 3)
    encoder.setBuffer(indirectDispatchArguments, offset: 0, index: 4)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart0_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
  }
  
  func buildSmallPart2_1(encoder: MTLComputeCommandEncoder) {
    encoder.setBuffer(bvhArguments, offset: 0, index: 0)
    encoder.setBuffer(globalCounters, offset: 0, index: 1)
    encoder.setBuffer(smallCounterMetadata, offset: 0, index: 2)
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 3)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart2_1
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: indirectDispatchArguments,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSize(width: 2, height: 8, depth: 8))
  }
}
