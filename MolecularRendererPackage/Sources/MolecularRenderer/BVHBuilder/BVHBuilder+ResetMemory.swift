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
