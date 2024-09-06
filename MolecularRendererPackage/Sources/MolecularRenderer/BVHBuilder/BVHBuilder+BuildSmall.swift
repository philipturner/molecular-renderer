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
//             Accumulate the reference count for each voxel.
//             Compact the reference offset for each voxel.
//             Fill the reference list for each voxel.
struct BVHBuildSmallPipelines {
  var buildSmallPart0_0: MTLComputePipelineState
  var buildSmallPart1_0: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    buildSmallPart0_0 = createPipeline(name: "buildSmallPart0_0")
    buildSmallPart1_0 = createPipeline(name: "buildSmallPart1_0")
  }
}

extension BVHBuilder {
  func buildSmallBVH(frameID: Int) {
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    buildSmallPart0_0(encoder: encoder)
    buildSmallPart1_0(encoder: encoder)
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

extension BVHBuilder {
  func buildSmallPart0_0(encoder: MTLComputeCommandEncoder) {
    encoder.setBuffer(globalCounters, offset: 0, index: 0)
    encoder.setBuffer(indirectDispatchArguments, offset: 0, index: 1)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart0_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
  }
  
  func buildSmallPart1_0(encoder: MTLComputeCommandEncoder) {
    encoder.setBuffer(compactedLargeCellMetadata, offset: 0, index: 0)
    encoder.setBuffer(convertedAtoms, offset: 0, index: 1)
    encoder.setBuffer(compactedSmallCellMetadata, offset: 0, index: 2)
    encoder.setBuffer(smallAtomReferences, offset: 0, index: 3)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart1_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: indirectDispatchArguments,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
  }
}
