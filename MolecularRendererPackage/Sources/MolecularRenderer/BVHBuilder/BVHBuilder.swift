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
  
  // Pipeline state objects (prepare).
  var resetMemory1DPipeline: MTLComputePipelineState
  var convertPipeline: MTLComputePipelineState
  var reduceBoxPart1Pipeline: MTLComputePipelineState
  var reduceBoxPart2Pipeline: MTLComputePipelineState
  var setIndirectArgumentsPipeline: MTLComputePipelineState
  
  // Pipeline state objects (build).
  var buildSmallPart1Pipeline: MTLComputePipelineState
  var buildSmallPart2Pipeline: MTLComputePipelineState
  var buildSmallPart3Pipeline: MTLComputePipelineState
  
  // Data buffers (per atom).
  var originalAtomsBuffers: [MTLBuffer]
  var convertedAtomsBuffer: MTLBuffer
  var boundingBoxPartialsBuffer: MTLBuffer
  
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
    
    // Initialize kernels for BVH construction.
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Function \(name) was not found in the library.")
      }
      return try! device.makeComputePipelineState(function: function)
    }
    
    // TODO: Make container objects that encapsulate the numerous pipelines.
    resetMemory1DPipeline = createPipeline(name: "resetMemory1D")
    convertPipeline = createPipeline(name: "convert")
    reduceBoxPart1Pipeline = createPipeline(name: "reduceBoxPart1")
    reduceBoxPart2Pipeline = createPipeline(name: "reduceBoxPart2")
    setIndirectArgumentsPipeline = createPipeline(name: "setIndirectArguments")
    
    buildSmallPart1Pipeline = createPipeline(name: "buildSmallPart1")
    buildSmallPart2Pipeline = createPipeline(name: "buildSmallPart2")
    buildSmallPart3Pipeline = createPipeline(name: "buildSmallPart3")
    
    // Allocate data buffers (per atom).
    func createBuffer(atomCount: Int) -> MTLBuffer {
      let bufferSize = atomCount * 16
      return device.makeBuffer(length: bufferSize)!
    }
    func createPartialsBuffer() -> MTLBuffer {
      let maxAtomCount = BVHBuilder.maxAtomCount
      let maxPartialCount = maxAtomCount / 128
      
      // Each partial is six 32-bit integers, strided to eight.
      let bufferSize = maxPartialCount * (8 * 4)
      return device.makeBuffer(length: bufferSize)!
    }
    originalAtomsBuffers = [
      createBuffer(atomCount: BVHBuilder.maxAtomCount),
      createBuffer(atomCount: BVHBuilder.maxAtomCount),
      createBuffer(atomCount: BVHBuilder.maxAtomCount),
    ]
    convertedAtomsBuffer = createBuffer(
      atomCount: 2 * BVHBuilder.maxAtomCount)
    boundingBoxPartialsBuffer = createPartialsBuffer()
    
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

extension BVHBuilder {
  /// Hard limit on the maximum atom count. We'll eventually make the
  /// program more sophisticated, enabling higher atom counts without the
  /// bandwidth of 120 * (4 million) atoms per second.
  static var maxAtomCount: Int {
    4 * 1024 * 1024
  }
}
