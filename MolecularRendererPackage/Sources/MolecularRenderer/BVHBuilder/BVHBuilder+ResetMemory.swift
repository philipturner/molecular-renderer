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
  func clearAllocationCounters(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 0)
    
    // Argument 1
    //
    // The first address should be 1, so that zeroes can be treated as null
    // pointers.
    var pattern: UInt32 = 1
    encoder.setBytes(&pattern, length: 4, index: 1)
    
    // Dispatch
    let pipeline = resetMemoryPipelines.resetMemory1D
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      MTLSize(width: 1024 / 128, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
  }
}
