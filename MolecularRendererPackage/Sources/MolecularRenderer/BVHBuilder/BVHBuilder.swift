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
  var cellGroupMarks: [MTLBuffer]
  var largeCounterMetadata: MTLBuffer
  var largeCellOffsets: MTLBuffer
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
    let movingAtomCount = 2 * 1024 * 1024
    originalAtoms = [
      createBuffer(length: movingAtomCount * 16),
      createBuffer(length: movingAtomCount * 16),
      createBuffer(length: movingAtomCount * 16),
    ]
    for i in 0..<3 {
      let buffer = originalAtoms[i]
      let label = "originalAtoms[\(i)]"
      buffer.label = label
    }
    
    atomMetadata = createBuffer(length: movingAtomCount * 8)
    relativeOffsets = createBuffer(length: movingAtomCount * 8 * 2)
    atomMetadata.label = "atomMetadata"
    relativeOffsets.label = "relativeOffsets"
    
    // Data buffers (per cell).
    let largeVoxelCount = 256 * 256 * 256
    let cellGroupCount = largeVoxelCount / (4 * 4 * 4)
    let occupiedLargeVoxelCount = 128 * 1024
    cellGroupMarks = [
      createBuffer(length: cellGroupCount),
      createBuffer(length: cellGroupCount),
    ]
    for i in 0..<2 {
      let buffer = cellGroupMarks[i]
      let label = "cellGroupMarks[\(i)]"
      buffer.label = label
    }
    
    largeCounterMetadata = createBuffer(length: largeVoxelCount * 8 * 4)
    largeCellOffsets = createBuffer(length: largeVoxelCount * 4)
    compactedLargeCellMetadata = createBuffer(
      length: occupiedLargeVoxelCount * 16)
    compactedSmallCellMetadata = createBuffer(
      length: occupiedLargeVoxelCount * 512 * 4)
    largeCounterMetadata.label = "largeCounterMetadata"
    largeCellOffsets.label = "largeCellOffsets"
    compactedLargeCellMetadata.label = "compactedLargeCellMetadata"
    compactedSmallCellMetadata.label = "compactedSmallCellMetadata"
    
    // Data buffers (per reference).
    let staticAtomCount = 8 * 1024 * 1024
    let largeReferenceCount = staticAtomCount * 2
    let smallReferenceCount = staticAtomCount * 16
    convertedAtoms = createBuffer(length: largeReferenceCount * 8)
    largeAtomReferences = createBuffer(length: largeReferenceCount * 4)
    smallAtomReferences = createBuffer(length: smallReferenceCount * 2)
    convertedAtoms.label = "convertedAtoms"
    largeAtomReferences.label = "largeAtomReferences"
    smallAtomReferences.label = "smallAtomReferences"
  }
}
