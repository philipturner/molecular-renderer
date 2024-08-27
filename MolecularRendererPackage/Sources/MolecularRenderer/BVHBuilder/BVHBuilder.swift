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
  
  // Pipeline state objects.
  var resetMemoryPipelines: BVHResetMemoryPipelines
  var preparePipelines: BVHPreparePipelines
  var buildSmallPipelines: BVHBuildSmallPipelines
  
  // Data buffers (per atom).
  var originalAtomsBuffers: [MTLBuffer]
  var convertedAtomsBuffer: MTLBuffer
  var boundingBoxPartialsBuffer: MTLBuffer
  
  // Data buffers (indirect dispatch).
  var bvhArgumentsBuffer: MTLBuffer
  var smallCellDispatchArguments8x8x8: MTLBuffer
  var globalAtomicCounters: MTLBuffer
  
  // Data buffers (other).
  var largeCellMetadata: MTLBuffer
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
    
    resetMemoryPipelines = BVHResetMemoryPipelines(library: library)
    preparePipelines = BVHPreparePipelines(library: library)
    buildSmallPipelines = BVHBuildSmallPipelines(library: library)
    
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
    
    // Allocate data buffers (indirect dispatch).
    bvhArgumentsBuffer = device.makeBuffer(length: 1024)!
    smallCellDispatchArguments8x8x8 = device.makeBuffer(length: 1024)!
    globalAtomicCounters = device.makeBuffer(length: 1024)!
    
    // Allocate data buffers (other).
    largeCellMetadata = device.makeBuffer(length: 64 * 64 * 64 * 4)!
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
