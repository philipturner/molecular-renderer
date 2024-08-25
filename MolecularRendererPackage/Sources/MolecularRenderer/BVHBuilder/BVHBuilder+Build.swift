//
//  BVHBuilder+Preprocessing.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/27/23.
//

import Metal

extension BVHBuilder {
  func buildBVH(frameID: Int) {
    let atoms = renderer.argumentContainer.currentAtoms
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    clearGlobalAtomicCounters(encoder: encoder)
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
  func clearGlobalAtomicCounters(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 0)
    
    // Dispatch
    encoder.setComputePipelineState(memset0Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(8, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  func clearSmallCellMetadata(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 0)
    
    // Dispatch
    let totalCells = createSmallVoxelCount()
    encoder.setComputePipelineState(memset0Pipeline)
    encoder.dispatchThreadgroups(
      MTLSizeMake((totalCells + 127) / 128, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  /// Encode the function `dense_grid_pass1`.
  func encodePass1(to encoder: MTLComputeCommandEncoder) {
    // Argument 0
    var bvhArguments = createBVHArguments()
    let bvhArgumentsLength = MemoryLayout<BVHArguments>.stride
    encoder.setBytes(&bvhArguments, length: bvhArgumentsLength, index: 0)
    
    // Arguments 1 - 2
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
    let totalCells = createSmallVoxelCount()
    encoder.setComputePipelineState(densePass2Pipeline)
    encoder.dispatchThreadgroups(
      MTLSizeMake((totalCells + 127) / 128, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  /// Encode the function `dense_grid_pass3`.
  func encodePass3(to encoder: MTLComputeCommandEncoder) {
    // Argument 0
    var bvhArguments = createBVHArguments()
    let bvhArgumentsLength = MemoryLayout<BVHArguments>.stride
    encoder.setBytes(&bvhArguments, length: bvhArgumentsLength, index: 0)
    
    // Arguments 1 - 3
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
