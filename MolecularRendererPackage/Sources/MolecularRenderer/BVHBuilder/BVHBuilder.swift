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
  var convertedAtoms: MTLBuffer
  var relativeOffsets: MTLBuffer
  
  // Data buffers (per cell).
  var largeCounterMetadata: MTLBuffer
  var largeCellMetadata: MTLBuffer
  var smallCellMetadata: MTLBuffer
  
  // Data buffers (per reference).
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
    originalAtoms = [
      createBuffer(length: BVHBuilder.maxAtomCount * 16),
      createBuffer(length: BVHBuilder.maxAtomCount * 16),
      createBuffer(length: BVHBuilder.maxAtomCount * 16),
    ]
    convertedAtoms = createBuffer(length: BVHBuilder.maxAtomCount * 16)
    relativeOffsets = createBuffer(length: BVHBuilder.maxAtomCount * 8 * 2)
    
    // Data buffers (per cell).
    let largeVoxelCount = 64 * 64 * 64
    let smallVoxelCount = 512 * 512 * 512
    largeCounterMetadata = createBuffer(length: largeVoxelCount * 8 * 4)
    largeCellMetadata = createBuffer(length: largeVoxelCount * 4 * 4)
    smallCellMetadata = createBuffer(length: smallVoxelCount * 4)
    
    // Data buffers (per reference).
    let largeReferenceCount = BVHBuilder.maxAtomCount * 2
    let smallReferenceCount = 64 * 1024 * 1024
    largeAtomReferences = createBuffer(length: largeReferenceCount * 4)
    smallAtomReferences = createBuffer(length: smallReferenceCount * 4)
  }
}

extension BVHBuilder {
  func bindElementRadii(encoder: MTLComputeCommandEncoder, index: Int) {
    let elementRadii = renderer.argumentContainer.elementRadii
    let byteCount = elementRadii.count * 4
    encoder.setBytes(elementRadii, length: byteCount, index: index)
  }
  
  func bindOriginalAtoms(encoder: MTLComputeCommandEncoder, index: Int) {
    let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
    let buffer = originalAtoms[tripleIndex]
    encoder.setBuffer(buffer, offset: 0, index: index)
  }
  
  var currentAtomCount: Int {
    let atoms = renderer.argumentContainer.currentAtoms
    return atoms.count
  }
}
