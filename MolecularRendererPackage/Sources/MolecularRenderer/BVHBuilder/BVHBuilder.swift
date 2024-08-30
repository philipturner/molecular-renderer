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
  var buildLargePipelines: BVHBuildLargePipelines
  var buildSmallPipelines: BVHBuildSmallPipelines
  
  // Data buffers (indirect dispatch).
  var globalCounters: MTLBuffer
  var bvhArguments: MTLBuffer
  var indirectDispatchArguments: MTLBuffer
  
  // Data buffers (per atom).
  var originalAtoms: [MTLBuffer]
  var convertedAtoms: MTLBuffer
  var relativeOffsets: MTLBuffer
  
  // Data buffers (per cell).
  var largeCounterMetadata: MTLBuffer
  var largeCellMetadata: MTLBuffer
  var smallCounterMetadata: MTLBuffer
  var smallCellMetadata: MTLBuffer
  
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
    
    buildLargePipelines = BVHBuildLargePipelines(library: library)
    buildSmallPipelines = BVHBuildSmallPipelines(library: library)
    
    func createBuffer(bytesPerAtom: Int) -> MTLBuffer {
      let bufferSize = BVHBuilder.maxAtomCount * bytesPerAtom
      return device.makeBuffer(length: bufferSize)!
    }
    
    // Allocate data buffers (indirect dispatch).
    globalCounters = device.makeBuffer(length: 1024 * 4)!
    bvhArguments = device.makeBuffer(length: 1024 * 4)!
    indirectDispatchArguments = device.makeBuffer(length: 1024 * 4)!
    
    // Allocate data buffers (per atom).
    originalAtoms = [
      createBuffer(bytesPerAtom: 16),
      createBuffer(bytesPerAtom: 16),
      createBuffer(bytesPerAtom: 16),
    ]
    convertedAtoms = createBuffer(bytesPerAtom: 2 * 16)
    relativeOffsets = createBuffer(bytesPerAtom: 16)
    
    // Allocate data buffers (per cell).
    largeCounterMetadata = device.makeBuffer(length: 64 * 64 * 64 * 8 * 4)!
    largeCellMetadata = device.makeBuffer(length: 64 * 64 * 64 * 4 * 4)!
    smallCounterMetadata = device.makeBuffer(length: 512 * 512 * 128 * 4 * 4)!
    smallCellMetadata = device.makeBuffer(length: 512 * 512 * 128 * 4)!
    
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
