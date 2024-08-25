//
//  BVHBuilder.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/17/23.
//

import Accelerate
import Metal
import simd
import QuartzCore

// There should be an option to enable this performance reporting mechanism, in
// the descriptor for 'MRRenderer'

class BVHBuilder {
  // Main rendering resources.
  var device: MTLDevice
  unowned var renderer: MRRenderer
  
  // BVH state information.
  var worldMinimum: SIMD3<Float> = .zero
  var worldMaximum: SIMD3<Float> = .zero
  
  // Pipeline state objects (for blitting).
  var memset0Pipeline: MTLComputePipelineState
  var memset1Pipeline: MTLComputePipelineState
  
  // Pipeline state objects.
  var convertPipeline: MTLComputePipelineState
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
    let convertFunction = library.makeFunction(name: "convert")!
    let densePass1Function = library.makeFunction(name: "dense_grid_pass1")!
    let densePass2Function = library.makeFunction(name: "dense_grid_pass2")!
    let densePass3Function = library.makeFunction(name: "dense_grid_pass3")!
    convertPipeline = try! device
      .makeComputePipelineState(function: convertFunction)
    densePass1Pipeline = try! device
      .makeComputePipelineState(function: densePass1Function)
    densePass2Pipeline = try! device
      .makeComputePipelineState(function: densePass2Function)
    densePass3Pipeline = try! device
      .makeComputePipelineState(function: densePass3Function)
    
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
