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
  var buildLargePipelines: BVHBuildLargePipelines
  var buildSmallPipelines: BVHBuildSmallPipelines
  
  // Data buffers (indirect dispatch).
  var globalAtomicCounters: MTLBuffer
  var bvhArgumentsBuffer: MTLBuffer
  var smallCellDispatchArguments8x8x8: MTLBuffer
  
  // Data buffers (per atom).
  var originalAtomsBuffers: [MTLBuffer]
  var convertedAtomsBuffer: MTLBuffer
  var relativeOffsetsBuffer: MTLBuffer
  
  // Data buffers (per cell).
  var largeCounterMetadata: MTLBuffer
  var largeCellMetadata: MTLBuffer
  var smallCellMetadata: MTLBuffer
  var smallCellCounters: MTLBuffer
  
  // Data buffers (other).
  var largeAtomReferences: MTLBuffer
  var smallAtomReferences: MTLBuffer
  
  public init(
    renderer: MRRenderer,
    library: MTLLibrary
  ) {
    let device = MTLCreateSystemDefaultDevice()!
    self.device = device
    self.renderer = renderer
    
    resetMemoryPipelines = BVHResetMemoryPipelines(library: library)
    buildLargePipelines = BVHBuildLargePipelines(library: library)
    buildSmallPipelines = BVHBuildSmallPipelines(library: library)
    
    func createBuffer(bytesPerAtom: Int) -> MTLBuffer {
      let bufferSize = BVHBuilder.maxAtomCount * bytesPerAtom
      return device.makeBuffer(length: bufferSize)!
    }
    
    // Allocate data buffers (indirect dispatch).
    globalAtomicCounters = device.makeBuffer(length: 1024 * 4)!
    bvhArgumentsBuffer = device.makeBuffer(length: 1024 * 4)!
    smallCellDispatchArguments8x8x8 = device.makeBuffer(length: 1024 * 4)!
    
    // Allocate data buffers (per atom).
    originalAtomsBuffers = [
      createBuffer(bytesPerAtom: 16),
      createBuffer(bytesPerAtom: 16),
      createBuffer(bytesPerAtom: 16),
    ]
    convertedAtomsBuffer = createBuffer(bytesPerAtom: 2 * 16)
    relativeOffsetsBuffer = createBuffer(bytesPerAtom: 16)
    
    // Allocate data buffers (per cell).
    largeCounterMetadata = device.makeBuffer(length: 64 * 64 * 64 * 8 * 4)!
    largeCellMetadata = device.makeBuffer(length: 64 * 64 * 64 * 4 * 4)!
    smallCellMetadata = device.makeBuffer(length: 512 * 512 * 512 * 4)!
    smallCellCounters = device.makeBuffer(length: 512 * 512 * 512 * 4)!
    
    // Allocate data buffers (other).
    largeAtomReferences = createBuffer(bytesPerAtom: 2 * 4)
    smallAtomReferences = device.makeBuffer(length: 64 * 1024 * 1024 * 4)!
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
