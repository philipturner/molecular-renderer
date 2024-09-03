//
//  BVHBuilder+BuildLarge.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/27/24.
//

import Metal
import QuartzCore

// Part 0
// - Kernel 0: Copy both static and updated atoms on CPU (for now).
//
// Part 1
// - Kernel 0: Reset the large counter metadata.
// - Kernel 1: Accumulate the reference count for each voxel.
//
// Part 2
// - Kernel 0: Reset the allocation and box counters.
// - Kernel 1: Compact the reference offset for each voxel.
// - Kernel 2: Copy atoms into converted format (for now).
struct BVHBuildLargePipelines {
  var buildLargePart1_0: MTLComputePipelineState
  var buildLargePart1_1: MTLComputePipelineState
  var buildLargePart2_0: MTLComputePipelineState
  var buildLargePart2_1: MTLComputePipelineState
  var buildLargePart2_2: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    buildLargePart1_0 = createPipeline(name: "buildLargePart1_0")
    buildLargePart1_1 = createPipeline(name: "buildLargePart1_1")
    buildLargePart2_0 = createPipeline(name: "buildLargePart2_0")
    buildLargePart2_1 = createPipeline(name: "buildLargePart2_1")
    buildLargePart2_2 = createPipeline(name: "buildLargePart2_2")
  }
}

extension BVHBuilder {
  func buildLargeBVH(frameID: Int) {
    let copyStart = CACurrentMediaTime()
    buildLargePart0_0()
    let copyEnd = CACurrentMediaTime()
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    buildLargePart1_0(encoder: encoder)
    buildLargePart1_1(encoder: encoder)
    buildLargePart2_0(encoder: encoder)
    buildLargePart2_1(encoder: encoder)
    buildLargePart2_2(encoder: encoder)
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

// MARK: - Cells
  
extension BVHBuilder {
  func buildLargePart1_0(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 1
    do {
      let currentIndex = renderer.argumentContainer.doubleBufferIndex()
      let previousIndex = (currentIndex + 1) % 2
      let previousMarks = cellGroupMarks[previousIndex]
      let currentMarks = cellGroupMarks[currentIndex]
      encoder.setBuffer(previousMarks, offset: 0, index: 0)
      encoder.setBuffer(currentMarks, offset: 0, index: 1)
    }
    
    // Argument 2
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 2)
    
    // Dispatch
    let pipeline = buildLargePipelines.buildLargePart1_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      MTLSize(width: 16, height: 16, depth: 16),
      threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))
  }
  
  func buildLargePart2_0(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    do {
      let allocatedMemory = 0
      let boundingBoxMin = 16
      let boundingBoxMax = 32
      encoder.setBuffer(globalCounters, offset: allocatedMemory, index: 0)
      encoder.setBuffer(globalCounters, offset: boundingBoxMin, index: 1)
      encoder.setBuffer(globalCounters, offset: boundingBoxMax, index: 2)
    }
    
    // Dispatch
    let pipeline = buildLargePipelines.buildLargePart2_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
  }
  
  func buildLargePart2_1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    do {
      let allocatedMemory = 0
      let boundingBoxMin = 16
      let boundingBoxMax = 32
      encoder.setBuffer(globalCounters, offset: allocatedMemory, index: 0)
      encoder.setBuffer(globalCounters, offset: boundingBoxMin, index: 1)
      encoder.setBuffer(globalCounters, offset: boundingBoxMax, index: 2)
    }
    
    // Argument 3
    do {
      let currentIndex = renderer.argumentContainer.doubleBufferIndex()
      let currentMarks = cellGroupMarks[currentIndex]
      encoder.setBuffer(currentMarks, offset: 0, index: 3)
    }
    
    // Arguments 4 - 5
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 4)
    encoder.setBuffer(largeCellMetadata, offset: 0, index: 5)
    encoder.setBuffer(compactedLargeCellIDs, offset: 0, index: 6)
    
    // Dispatch
    let pipeline = buildLargePipelines.buildLargePart2_1
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      MTLSize(width: 16, height: 16, depth: 16),
      threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))
  }
}

// MARK: - Atoms

extension BVHBuilder {
  func buildLargePart0_0() {
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
  
  func buildLargePart1_1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 5
    bindAtomArguments(encoder: encoder)
    
    // Argument 6
    do {
      let currentIndex = renderer.argumentContainer.doubleBufferIndex()
      let currentMarks = cellGroupMarks[currentIndex]
      encoder.setBuffer(currentMarks, offset: 0, index: 6)
    }
    
    // Argument 7
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 7)
    
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
  
  func buildLargePart2_2(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 5
    bindAtomArguments(encoder: encoder)
    
    // Arguments 6 - 8
    encoder.setBuffer(convertedAtoms, offset: 0, index: 6)
    encoder.setBuffer(atomMotionVectors, offset: 0, index: 7)
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 8)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart2_2
      encoder.setComputePipelineState(pipeline)
      
      let sourceArray = renderer.argumentContainer.currentAtoms
      encoder.dispatchThreads(
        MTLSize(width: sourceArray.count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
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
}
