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
  
  // Part 2
  // - Kernel 0: Reset the allocation and box counters.
  // - Kernel 1: Compact the reference offset for each voxel.
  // - Kernel 2: Copy atoms into converted format (for now).
  
  var buildLargePart1_1: MTLComputePipelineState
  var buildLargePart2_0: MTLComputePipelineState
  var buildLargePart2_1: MTLComputePipelineState
  var buildLargePart3_0: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    buildLargePart1_1 = createPipeline(name: "buildLargePart1_1")
    buildLargePart2_0 = createPipeline(name: "buildLargePart2_0")
    buildLargePart2_1 = createPipeline(name: "buildLargePart2_1")
    buildLargePart3_0 = createPipeline(name: "buildLargePart3_0")
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
    buildLargePart3_0(encoder: encoder)
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
    let byteCount = sourceArray.count * 16
    
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
    
    // Argument 1
    var pattern: UInt32 = 0
    encoder.setBytes(&pattern, length: 4, index: 1)
    
    // Dispatch
    let pipeline = resetMemoryPipelines.resetMemory1D
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      MTLSize(width: 64 * 64 * 64 * 8 / 128, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
  }
  
  func buildLargePart1_1(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    renderer.atomRadii.withUnsafeBufferPointer {
      let length = $0.count * 4
      encoder.setBytes($0.baseAddress!, length: length, index: 0)
    }
    
    // Argument 1
    do {
      let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
      let originalAtomsBuffer = originalAtomsBuffers[tripleIndex]
      encoder.setBuffer(originalAtomsBuffer, offset: 0, index: 1)
    }
    
    // Arguments 2 - 3
    do {
      let offset1 = 0
      let offset2 = relativeOffsetsBuffer.length / 2
      encoder.setBuffer(relativeOffsetsBuffer, offset: offset1, index: 2)
      encoder.setBuffer(relativeOffsetsBuffer, offset: offset2, index: 3)
    }
    
    // Argument 4
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 4)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart1_1
      encoder.setComputePipelineState(pipeline)
      
      let atoms = renderer.argumentContainer.currentAtoms
      encoder.dispatchThreads(
        MTLSize(width: atoms.count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
  
  func buildLargePart2_0(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 0)
    encoder.setBuffer(globalAtomicCounters, offset: 16, index: 1)
    encoder.setBuffer(globalAtomicCounters, offset: 32, index: 2)
    
    // Dispatch
    let pipeline = buildLargePipelines.buildLargePart2_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
  }
  
  func buildLargePart2_1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 0)
    encoder.setBuffer(globalAtomicCounters, offset: 16, index: 1)
    encoder.setBuffer(globalAtomicCounters, offset: 32, index: 2)
    
    // Arguments 3 - 4
    encoder.setBuffer(largeCounterMetadata, offset: 0, index: 3)
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
