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
  var indirectDispatchArguments: MTLBuffer
  
  // Data buffers (per atom).
  var originalAtoms: [MTLBuffer]
  var atomMetadata: MTLBuffer
  var relativeOffsets: MTLBuffer
  
  // Data buffers (per cell).
  var cellGroupMarks: MTLBuffer
  var largeCounterMetadata: MTLBuffer
  var largeCellOffsets: MTLBuffer
  
  // Data buffers (per occupied cell).
  var compactedLargeCellMetadata: MTLBuffer
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
    indirectDispatchArguments = createBuffer(length: 1024 * 4)
    globalCounters.label = "globalCounters"
    indirectDispatchArguments.label = "indirectDispatchArguments"
    
    // Data buffers (per atom).
    let atomCount = 2 * 1024 * 1024
    originalAtoms = [
      createBuffer(length: atomCount * 16),
      createBuffer(length: atomCount * 16),
      createBuffer(length: atomCount * 16),
    ]
    atomMetadata = createBuffer(length: atomCount * 8)
    relativeOffsets = createBuffer(length: atomCount * 8 * 2)
    
    // Data buffers (per cell).
    let largeVoxelCount = 128 * 128 * 128
    let cellGroupCount = largeVoxelCount / (4 * 4 * 4)
    cellGroupMarks = createBuffer(length: cellGroupCount)
    largeCounterMetadata = createBuffer(length: largeVoxelCount * 8 * 4)
    largeCellOffsets = createBuffer(length: largeVoxelCount * 4)
    
    // Data buffers (per occupied cell).
    let occupiedLargeVoxelCount = 64 * 1024
    compactedLargeCellMetadata = createBuffer(
      length: occupiedLargeVoxelCount * 16)
    compactedSmallCellMetadata = createBuffer(
      length: occupiedLargeVoxelCount * 512 * 4)
    
    // Data buffers (per reference).
    let largeReferenceCount = atomCount * 2
    let smallReferenceCount = atomCount * 16
    convertedAtoms = createBuffer(length: largeReferenceCount * 8)
    largeAtomReferences = createBuffer(length: largeReferenceCount * 4)
    smallAtomReferences = createBuffer(length: smallReferenceCount * 2)
  }
}
