//
//  BVHBuilder+BuildSmall.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/27/23.
//

import Metal

extension BVHBuilder {
  func buildSmallBVH(frameID: Int) {
    let atoms = renderer.argumentContainer.currentAtoms
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    setAllocationCounter(encoder: encoder)
    clearSmallCellMetadata(encoder: encoder)
    
    encodePass1(to: encoder)
    encodePass2(to: encoder)
    encodePass3(to: encoder)
    encoder.endEncoding()
    
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let frameReporter = self.renderer.frameReporter!
      frameReporter.queue.sync {
        let index = frameReporter.index(of: frameID)
        guard let index else {
          return
        }
        
        let executionTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        frameReporter.reports[index].buildTime = executionTime
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
    encoder.setComputePipelineState(resetMemory1DPipeline)
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
    encoder.setComputePipelineState(resetMemory1DPipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: smallCellDispatchArguments,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
}

extension BVHBuilder {
  /// Encode the function `dense_grid_pass1`.
  func encodePass1(to encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 0)
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 1)
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 2)
    
    // Dispatch
    let atoms = renderer.argumentContainer.currentAtoms
    encoder.setComputePipelineState(densePass1Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  /// Encode the function `dense_grid_pass2`.
  func encodePass2(to encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 0)
    encoder.setBuffer(smallCellCounters, offset: 0, index: 1)
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 2)
    
    // Dispatch
    encoder.setComputePipelineState(densePass2Pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: smallCellDispatchArguments,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  /// Encode the function `dense_grid_pass3`.
  func encodePass3(to encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 3
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 0)
    encoder.setBuffer(smallCellCounters, offset: 0, index: 1)
    encoder.setBuffer(smallCellAtomReferences, offset: 0, index: 2)
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 3)
    
    // Dispatch
    let atoms = renderer.argumentContainer.currentAtoms
    encoder.setComputePipelineState(densePass3Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
}
