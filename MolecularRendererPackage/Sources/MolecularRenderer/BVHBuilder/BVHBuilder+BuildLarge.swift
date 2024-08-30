//
//  BVHBuilder+BuildLarge.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/27/24.
//

import Metal
import QuartzCore

struct BVHBuildLargePipelines {
  // Part 0
  // - Kernel 0: Copy both static and updated atoms on CPU (for now).
  
  // Part 1
  // - Kernel 0: Reset the large counter metadata.
  // - Kernel 1: Accumulate the reference count for each voxel.
  var buildLargePart1_0: MTLComputePipelineState
  var buildLargePart1_1: MTLComputePipelineState
  
  // Part 2
  // - Kernel 0: Reset the allocation and box counters.
  // - Kernel 1: Compact the reference offset for each voxel.
  // - Kernel 2: Copy atoms into converted format (for now).
  var buildLargePart2_0: MTLComputePipelineState
  var buildLargePart2_1: MTLComputePipelineState
  
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
  }
}

extension BVHBuilder {
  func buildLargeBVH(frameID: Int) {
    let copyStart = CACurrentMediaTime()
    buildLargePart0_0()
    let copyEnd = CACurrentMediaTime()
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
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

// MARK: - Part 0

extension BVHBuilder {
  func buildLargePart0_0() {
    // Destination
    let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
    let destinationBuffer = originalAtoms[tripleIndex]
    let destinationPointer = destinationBuffer.contents()
    
    // Source
    let sourceArray = renderer.argumentContainer.currentAtoms
    
    // Number of Bytes
    let byteCount = currentAtomCount * 16
    
    // Function Call
    memcpy(
      /*__dst*/ destinationPointer,
      /*__src*/ sourceArray,
      /*__n*/   byteCount)
  }
}

// MARK: - Part 1
  
extension BVHBuilder {
  func buildLargePart1_0(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 0)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart1_0
      encoder.setComputePipelineState(pipeline)
      
      let cellCount = largeCounterMetadata.length / (8 * 4)
      encoder.dispatchThreadgroups(
        MTLSize(width: cellCount / 128, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
  
  func buildLargePart1_1(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    bindElementRadii(encoder: encoder, index: 0)
    
    // Argument 1
    bindOriginalAtoms(encoder: encoder, index: 1)
    
    // Arguments 2 - 3
    do {
      let offset1 = 0
      let offset2 = relativeOffsets.length / 2
      encoder.setBuffer(relativeOffsets, offset: offset1, index: 2)
      encoder.setBuffer(relativeOffsets, offset: offset2, index: 3)
    }
    
    // Argument 4
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 4)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart1_1
      encoder.setComputePipelineState(pipeline)
      
      let atomCount = currentAtomCount
      encoder.dispatchThreads(
        MTLSize(width: atomCount, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
}

// MARK: - Part 2

extension BVHBuilder {
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
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 3)
    
    // Argument 4
    encoder.setBuffer(largeCellMetadata, offset: 0, index: 4)
    
    // Dispatch
    let pipeline = buildLargePipelines.buildLargePart2_1
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      MTLSize(width: 16, height: 16, depth: 16),
      threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))
  }
  
  func buildLargePart3_0(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    renderer.atomRadii.withUnsafeBufferPointer {
      let length = $0.count * 4
      encoder.setBytes($0.baseAddress!, length: length, index: 0)
    }
    
    // Arguments 1 - 2
    do {
      let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
      let originalAtomsBuffer = originalAtomsBuffers[tripleIndex]
      encoder.setBuffer(originalAtomsBuffer, offset: 0, index: 1)
      encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 2)
    }
    
    // Arguments 3 - 4
    do {
      let offset1 = 0
      let offset2 = relativeOffsetsBuffer.length / 2
      encoder.setBuffer(relativeOffsetsBuffer, offset: offset1, index: 3)
      encoder.setBuffer(relativeOffsetsBuffer, offset: offset2, index: 4)
    }
    
    // Arguments 5 - 6
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 5)
    encoder.setBuffer(largeAtomReferences, offset: 0, index: 6)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart3_0
      encoder.setComputePipelineState(pipeline)
      
      let atoms = renderer.argumentContainer.currentAtoms
      encoder.dispatchThreads(
        MTLSize(width: atoms.count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
}
