//
//  BVHBuilder+BuildLarge.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/27/24.
//

import Metal
import QuartzCore

// Part 0
// - Kernel 0: Reset the allocation counter.
//             Reset the bounding box counter.
//             Reset the cell group marks.
// - Kernel 1: Accumulate the reference count for each voxel.
//
// Part 1
// - Kernel 0: Reduce the bounding box.
//             Compact the reference offset for each voxel.
// - Kernel 1: Copy atoms into converted format.
//
// Part 2
// - Kernel 0: Convert the bounding box to FP32.
//             Reset the large counter metadata.
struct BVHBuildLargePipelines {
  var buildLargePart0_0: MTLComputePipelineState
  var buildLargePart0_1: MTLComputePipelineState
  var buildLargePart1_0: MTLComputePipelineState
  var buildLargePart1_1: MTLComputePipelineState
  var buildLargePart2_0: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      let function = library.makeFunction(name: name)
      guard let function else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    buildLargePart0_0 = createPipeline(name: "buildLargePart0_0")
    buildLargePart0_1 = createPipeline(name: "buildLargePart0_1")
    buildLargePart1_0 = createPipeline(name: "buildLargePart1_0")
    buildLargePart1_1 = createPipeline(name: "buildLargePart1_1")
    buildLargePart2_0 = createPipeline(name: "buildLargePart2_0")
  }
}

extension BVHBuilder {
  func buildLargeBVH(frameID: Int) {
    let copyStart = CACurrentMediaTime()
    copyAtomsIntoBuffer()
    let copyEnd = CACurrentMediaTime()
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    buildLargePart0_0(encoder: encoder)
    buildLargePart0_1(encoder: encoder)
    buildLargePart1_0(encoder: encoder)
    buildLargePart1_1(encoder: encoder)
    buildLargePart2_0(encoder: encoder)
    encoder.endEncoding()
    
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let frameReporter = self.renderer.frameReporter!
      frameReporter.queue.sync {
        let index = frameReporter.index(of: frameID)
        guard let index else {
          return
        }
        
        let copyTime = copyEnd - copyStart
        frameReporter.reports[index].copyTime = copyTime
        
        let executionTime =
        commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        frameReporter.reports[index].buildLargeTime = executionTime
      }
    }
    commandBuffer.commit()
  }
}

// MARK: - Atoms

extension BVHBuilder {
  func copyAtomsIntoBuffer() {
    // Destination
    let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
    let destinationBuffer = originalAtoms[tripleIndex]
    let destinationPointer = destinationBuffer.contents()
    
    // Source
    let sourceArray = renderer.argumentContainer.currentAtoms
    
    // Number of Bytes
    let atomCount = sourceArray.count
    let byteCount = atomCount * 16
    
    // Function Call
    memcpy(
      /*__dst*/ destinationPointer,
      /*__src*/ sourceArray,
      /*__n*/   byteCount)
  }
  
  func bindAtomArguments(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    do {
      var flag = renderer.argumentContainer.useAtomMotionVectors
      encoder.setBytes(&flag, length: 1, index: 0)
    }
    
    // Argument 1
    do {
      let elementRadii = renderer.argumentContainer.elementRadii
      let byteCount = elementRadii.count * 2
      encoder.setBytes(elementRadii, length: byteCount, index: 1)
    }
    
    // Arguments 2 - 3
    do {
      let currentIndex = renderer.argumentContainer.tripleBufferIndex()
      let previousIndex = (currentIndex + 2) % 3
      let previousAtoms = originalAtoms[previousIndex]
      let currentAtoms = originalAtoms[currentIndex]
      encoder.setBuffer(previousAtoms, offset: 0, index: 2)
      encoder.setBuffer(currentAtoms, offset: 0, index: 3)
    }
    
    // Arguments 4 - 5
    do {
      let offset1 = 0
      let offset2 = relativeOffsets.length / 2
      encoder.setBuffer(relativeOffsets, offset: offset1, index: 4)
      encoder.setBuffer(relativeOffsets, offset: offset2, index: 5)
    }
  }
  
  func buildLargePart0_1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 5
    bindAtomArguments(encoder: encoder)
    
    encoder.setBuffer(cellGroupMarks, offset: 0, index: 6)
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 7)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart0_1
      encoder.setComputePipelineState(pipeline)
      
      let sourceArray = renderer.argumentContainer.currentAtoms
      encoder.dispatchThreads(
        MTLSize(width: sourceArray.count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
  
  func buildLargePart1_1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 5
    bindAtomArguments(encoder: encoder)
    
    encoder.setBuffer(atomMetadata, offset: 0, index: 6)
    encoder.setBuffer(convertedAtoms, offset: 0, index: 7)
    encoder.setBuffer(largeAtomReferences, offset: 0, index: 8)
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 9)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart1_1
      encoder.setComputePipelineState(pipeline)
      
      let sourceArray = renderer.argumentContainer.currentAtoms
      encoder.dispatchThreads(
        MTLSize(width: sourceArray.count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
}

// MARK: - Cells
  
extension BVHBuilder {
  // The dimensions must not exceed 256 nm, because that's how much memory we
  // have allocated. It must not go smaller than 32 nm, because then we have
  // some glitches with SIMD lanes being inactive.
  private static var worldVolumeInNm: Int { 256 }
  private static var cellGroupGridWidth: Int { worldVolumeInNm / 8 }
  private static var largeVoxelGridWidth: Int { worldVolumeInNm / 2 }
  private static var smallVoxelGridWidth: Int { worldVolumeInNm * 4 }
  
  func buildLargePart0_0(encoder: MTLComputeCommandEncoder) {
    encoder.setBuffer(globalCounters, offset: 0, index: 0)
    encoder.setBuffer(globalCounters, offset: 128, index: 1)
    encoder.setBuffer(cellGroupMarks, offset: 0, index: 2)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart0_0
      encoder.setComputePipelineState(pipeline)
      
      let gridSize = Self.cellGroupGridWidth
      encoder.dispatchThreads(
        MTLSize(width: gridSize, height: gridSize, depth: gridSize),
        threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))
    }
  }
  
  func buildLargePart1_0(encoder: MTLComputeCommandEncoder) {
    encoder.setBuffer(globalCounters, offset: 0, index: 0)
    encoder.setBuffer(globalCounters, offset: 128, index: 1)
    encoder.setBuffer(cellGroupMarks, offset: 0, index: 2)
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 3)
    encoder.setBuffer(largeCellOffsets, offset: 0, index: 4)
    encoder.setBuffer(compactedLargeCellMetadata, offset: 0, index: 5)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart1_0
      encoder.setComputePipelineState(pipeline)
      
      let gridSize = Self.cellGroupGridWidth
      encoder.dispatchThreadgroups(
        MTLSize(width: gridSize, height: gridSize, depth: gridSize),
        threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))
    }
  }
  
  func buildLargePart2_0(encoder: MTLComputeCommandEncoder) {
    encoder.setBuffer(globalCounters, offset: 128, index: 0)
    encoder.setBuffer(cellGroupMarks, offset: 0, index: 1)
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 2)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart2_0
      encoder.setComputePipelineState(pipeline)
      
      let gridSize = Self.cellGroupGridWidth
      encoder.dispatchThreadgroups(
        MTLSize(width: gridSize, height: gridSize, depth: gridSize),
        threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))
    }
  }
}
