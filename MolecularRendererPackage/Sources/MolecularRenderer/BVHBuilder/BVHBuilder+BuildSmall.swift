//
//  BVHBuilder+BuildSmall.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/27/23.
//

import Metal

struct BVHBuildSmallPipelines {
  // Part 0
  // - Kernel 0: Encode the indirect dispatch arguments.
  //
  // Part 1
  // - Kernel 0: Reset the small counter metadata.
  // - Kernel 1: Accumulate the reference count for each voxel.
  //
  // Part 2:
  // - Kernel 0: Reset the allocation counter.
  // - Kernel 1: Compact the reference offset for each voxel.
  // - Kernel 2: Fill the reference list for each voxel.
  
  var buildSmallPart1_0: MTLComputePipelineState
  var buildSmallPart1_2: MTLComputePipelineState
  var buildSmallPart2_0: MTLComputePipelineState
  var buildSmallPart2_1: MTLComputePipelineState
  var buildSmallPart3_0: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    buildSmallPart1_0 = createPipeline(name: "buildSmallPart1_0")
    buildSmallPart1_2 = createPipeline(name: "buildSmallPart1_2")
    buildSmallPart2_0 = createPipeline(name: "buildSmallPart2_0")
    buildSmallPart2_1 = createPipeline(name: "buildSmallPart2_1")
    buildSmallPart3_0 = createPipeline(name: "buildSmallPart3_0")
  }
}

extension BVHBuilder {
  func buildSmallBVH(frameID: Int) {
    let atoms = renderer.argumentContainer.currentAtoms
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    buildSmallPart1_0(encoder: encoder)
    buildSmallPart1_1(encoder: encoder)
    buildSmallPart1_2(encoder: encoder)
    buildSmallPart2_0(encoder: encoder)
    buildSmallPart2_1(encoder: encoder)
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
        
        let executionTime = 
        commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        frameReporter.reports[index].buildSmallTime = executionTime
      }
    }
    commandBuffer.commit()
  }
}

// MARK: - New Kernels

extension BVHBuilder {
  func buildSmallPart1_0(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 0)
    encoder.setBuffer(globalAtomicCounters, offset: 16, index: 1)
    encoder.setBuffer(globalAtomicCounters, offset: 32, index: 2)
    
    // Arguments 3 - 4
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 3)
    encoder.setBuffer(smallCellDispatchArguments8x8x8, offset: 0, index: 4)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart1_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
  }
}

// MARK: - Old Kernels

extension BVHBuilder {
  func clearSmallCellMetadata(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 1
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 0)
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 1)
    
    // Dispatch
    let pipeline = buildSmallPipelines.clearSmallCellMetadata
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: smallCellDispatchArguments8x8x8,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSize(width: 2, height: 8, depth: 8))
  }
  
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
      MTLSize(width: atoms.count, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
  }
  
  func buildSmallPart2(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 3
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 0)
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 1)
    encoder.setBuffer(smallCellCounters, offset: 0, index: 2)
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 3)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart2
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: smallCellDispatchArguments8x8x8,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSize(width: 2, height: 8, depth: 8))
  }
  
  func buildSmallPart3(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 3
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 0)
    encoder.setBuffer(smallCellCounters, offset: 0, index: 1)
    encoder.setBuffer(smallAtomReferences, offset: 0, index: 2)
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 3)
    
    // Dispatch
    let atoms = renderer.argumentContainer.currentAtoms
    let pipeline = buildSmallPipelines.buildSmallPart3
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: atoms.count, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
  }
}
