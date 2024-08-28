//
//  BVHBuilder+ResetMemory.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/26/24.
//

import Metal

struct BVHResetMemoryPipelines {
  var resetMemory1D: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    resetMemory1D = createPipeline(name: "resetMemory1D")
  }
}

extension BVHBuilder {
  func clearAdditionCounters(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 0)
    
    // Argument 1
    var pattern: UInt32 = .zero
    encoder.setBytes(&pattern, length: 4, index: 1)
    
    // Dispatch
    let pipeline = resetMemoryPipelines.resetMemory1D
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      MTLSize(width: 1024 / 128, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
  }
  
  func clearBoxCounters(encoder: MTLComputeCommandEncoder) {
    func fillRegion(startSlotID: Int, value: Int32) {
      // Argument 0
      let offset = startSlotID * 4
      encoder.setBuffer(globalAtomicCounters, offset: offset, index: 0)
      
      // Argument 1
      var pattern: Int32 = value
      encoder.setBytes(&pattern, length: 4, index: 1)
      
      // Dispatch four threads, to fill four slots.
      let pipeline = resetMemoryPipelines.resetMemory1D
      encoder.setComputePipelineState(pipeline)
      encoder.dispatchThreads(
        MTLSize(width: 4, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
    
    // Minimum counter: start at +infinity
    fillRegion(startSlotID: 0, value: Int32.max)
    
    // Maximum counter: start at -infinity
    fillRegion(startSlotID: 4, value: Int32.min)
  }
  
  func clearLargeInputMetadata(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(largeInputMetadata, offset: 0, index: 0)
    
    // Argument 1
    var pattern: UInt32 = .zero
    encoder.setBytes(&pattern, length: 4, index: 1)
    
    // Dispatch
    do {
      let pipeline = resetMemoryPipelines.resetMemory1D
      encoder.setComputePipelineState(pipeline)
      
      let largeCellCount = largeInputMetadata.length / 4
      encoder.dispatchThreadgroups(
        MTLSize(width: largeCellCount / 128, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
}
