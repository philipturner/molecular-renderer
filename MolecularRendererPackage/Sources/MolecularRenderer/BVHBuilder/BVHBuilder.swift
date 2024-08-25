//
//  BVHBuilder.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/17/23.
//

import Metal

class BVHBuilder {
  // Main rendering resources.
  var device: MTLDevice
  unowned var renderer: MRRenderer
  
  // BVH state information.
  var worldMinimum: SIMD3<Int32> = .zero
  var worldMaximum: SIMD3<Int32> = .zero
  
  // Pipeline state objects (for blitting).
  var memset0Pipeline: MTLComputePipelineState
  var memset1Pipeline: MTLComputePipelineState
  
  // Pipeline state objects.
  var convertPipeline: MTLComputePipelineState
  var setIndirectArgumentsPipeline: MTLComputePipelineState
  var densePass1Pipeline: MTLComputePipelineState
  var densePass2Pipeline: MTLComputePipelineState
  var densePass3Pipeline: MTLComputePipelineState
  
  // Data buffers (per atom).
  var originalAtomsBuffers: [MTLBuffer]
  var convertedAtomsBuffer: MTLBuffer
  
  // Data buffers (allocation).
  var bvhArgumentsBuffer: MTLBuffer
  var smallCellDispatchArguments: MTLBuffer
  var globalAtomicCounters: MTLBuffer
  
  // Data buffers (other).
  var smallCellMetadata: MTLBuffer
  var smallCellCounters: MTLBuffer
  var smallCellAtomReferences: MTLBuffer
  
  public init(
    renderer: MRRenderer,
    library: MTLLibrary
  ) {
    let device = MTLCreateSystemDefaultDevice()!
    self.device = device
    self.renderer = renderer
    
    // Initialize the memset kernels.
    func createMemsetPipeline(value: UInt32) -> MTLComputePipelineState {
      let constants = MTLFunctionConstantValues()
      var pattern4 = value
      constants.setConstantValue(&pattern4, type: .uint, index: 1000)
      
      let function = try! library.makeFunction(
        name: "memset_pattern4", constantValues: constants)
      return try! device.makeComputePipelineState(function: function)
    }
    memset0Pipeline = createMemsetPipeline(value: 0x0000_0000)
    memset1Pipeline = createMemsetPipeline(value: 0xFFFF_FFFF)
    
    // Initialize kernels for BVH construction.
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Function \(name) was not found in the library.")
      }
      return try! device.makeComputePipelineState(function: function)
    }
    convertPipeline = createPipeline(name: "convert")
    setIndirectArgumentsPipeline = createPipeline(name: "setIndirectArguments")
    densePass1Pipeline = createPipeline(name: "densePass1")
    densePass2Pipeline = createPipeline(name: "densePass2")
    densePass3Pipeline = createPipeline(name: "densePass3")
    
    // Allocate data buffers (per atom).
    func createAtomBuffer() -> MTLBuffer {
      // Limited to 4 million atoms for now.
      let bufferSize: Int = (4 * 1024 * 1024) * 16
      return device.makeBuffer(length: bufferSize)!
    }
    originalAtomsBuffers = [
      createAtomBuffer(),
      createAtomBuffer(),
      createAtomBuffer(),
    ]
    convertedAtomsBuffer = createAtomBuffer()
    
    // Allocate data buffers (allocation).
    bvhArgumentsBuffer = device.makeBuffer(length: 1024)!
    smallCellDispatchArguments = device.makeBuffer(length: 1024)!
    globalAtomicCounters = device.makeBuffer(length: 1024)!
    
    // Allocate data buffers (other).
    smallCellMetadata = device.makeBuffer(length: 512 * 512 * 512 * 4)!
    smallCellCounters = device.makeBuffer(length: 512 * 512 * 512 * 4)!
    smallCellAtomReferences = device.makeBuffer(length: 64 * 1024 * 1024 * 4)!
  }
}
