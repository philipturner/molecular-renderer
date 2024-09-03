//
//  BVHBuilder.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/17/23.
//

import Metal

class BVHBuilder {
  var device: MTLDevice
  unowned var renderer: MRRenderer
  
  // Pipeline state objects.
  var buildLargePipelines: BVHBuildLargePipelines
  var buildSmallPipelines: BVHBuildSmallPipelines
  
  // Data buffers (global).
  var globalCounters: MTLBuffer
  var bvhArguments: MTLBuffer
  var indirectDispatchArguments: MTLBuffer
  
  // Data buffers (per atom).
  var originalAtoms: [MTLBuffer]
  var atomMetadata: MTLBuffer
  var relativeOffsets: MTLBuffer
  
  // Data buffers (per cell).
  var cellGroupMarks: [MTLBuffer]
  var largeCounterMetadata: MTLBuffer
  var largeCellMetadata: MTLBuffer
  var compactedLargeCellIDs: MTLBuffer
  var compactedSmallCellMetadata: MTLBuffer
  
  // Data buffers (per reference).
  var convertedAtoms: MTLBuffer
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
    
    func createBuffer(length: Int) -> MTLBuffer {
      let buffer = device.makeBuffer(length: length)
      guard let buffer else {
        fatalError("Could not create buffer, likely ran out of memory.")
      }
      return buffer
    }
    
    // Data buffers (global).
    globalCounters = createBuffer(length: 1024 * 4)
    bvhArguments = createBuffer(length: 1024 * 4)
    indirectDispatchArguments = createBuffer(length: 1024 * 4)
    
    // Data buffers (per atom).
    let atomCount = 4 * 1024 * 1024
    originalAtoms = [
      createBuffer(length: atomCount * 16),
      createBuffer(length: atomCount * 16),
      createBuffer(length: atomCount * 16),
    ]
    atomMetadata = createBuffer(length: atomCount * 8)
    relativeOffsets = createBuffer(length: atomCount * 8 * 2)
    
    // Data buffers (per cell).
    let largeVoxelCount = 64 * 64 * 64
    let smallVoxelCount = 16 * 1024 * 1024
    cellGroupMarks = [
      createBuffer(length: 16 * 16 * 16),
      createBuffer(length:  16 * 16 * 16),
    ]
    largeCounterMetadata = createBuffer(length: largeVoxelCount * 8 * 4)
    largeCellMetadata = createBuffer(length: largeVoxelCount * 16)
    compactedLargeCellIDs = createBuffer(length: largeVoxelCount * 4)
    compactedSmallCellMetadata = createBuffer(length: smallVoxelCount * 4)
    
    // Data buffers (per reference).
    let largeReferenceCount = 8 * 1024 * 1024
    let smallReferenceCount = 64 * 1024 * 1024
    convertedAtoms = createBuffer(length: largeReferenceCount * 8)
    largeAtomReferences = createBuffer(length: largeReferenceCount * 4)
    smallAtomReferences = createBuffer(length: smallReferenceCount * 2)
  }
}
