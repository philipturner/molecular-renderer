//
//  BVHBuilder+BuildSmall.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/27/23.
//

import Metal

// Part 0
// - Kernel 0: Encode the indirect dispatch arguments.
//
// Part 1
// - Kernel 0: Reset the small counter metadata.
// - Kernel 1: Accumulate the reference count for each voxel.
//
// Part 2:
// - Kernel 0: Reset the allocation counter.
// - Kernel 1: Compact the reference offset for each voxel.
// - Kernel 2: Fill the reference list for each voxel.
struct BVHBuildSmallPipelines {
  var buildSmallPart0_0: MTLComputePipelineState
  var buildSmallPart1_0: MTLComputePipelineState
  var buildSmallPart1_1: MTLComputePipelineState
  var buildSmallPart2_0: MTLComputePipelineState
  var buildSmallPart2_1: MTLComputePipelineState
  var buildSmallPart2_2: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    buildSmallPart0_0 = createPipeline(name: "buildSmallPart0_0")
    buildSmallPart1_0 = createPipeline(name: "buildSmallPart1_0")
    buildSmallPart1_1 = createPipeline(name: "buildSmallPart1_1")
    buildSmallPart2_0 = createPipeline(name: "buildSmallPart2_0")
    buildSmallPart2_1 = createPipeline(name: "buildSmallPart2_1")
    buildSmallPart2_2 = createPipeline(name: "buildSmallPart2_2")
  }
}

extension BVHBuilder {
  func buildSmallBVH(frameID: Int) {
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    buildSmallPart0_0(encoder: encoder)
    buildSmallPart1_0(encoder: encoder)
    buildSmallPart1_1(encoder: encoder)
//    buildSmallPart2_0(encoder: encoder)
//    buildSmallPart2_1(encoder: encoder)
//    buildSmallPart2_2(encoder: encoder)
    encoder.endEncoding()
    
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let frameReporter = self.renderer.frameReporter!
      frameReporter.queue.sync {
        let index = frameReporter.index(of: frameID)
        guard let index else {
          return
        }
        
        let executionTime = 
        commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        frameReporter.reports[index].buildSmallTime = executionTime
      }
    }
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    let debugData = relativeOffsetsDebug.contents()
      .assumingMemoryBound(to: SIMD32<UInt16>.self)
    let simdCount = (currentAtomCount + 31) / 32
    
    var singleThreadBins = [Int](repeating: 0, count: 129)
    var entireSIMDBins = [Int](repeating: 0, count: 129)
    let binThresholds: [Int] = [1, 2, 4, 8, 12, 16, 24, 32]
    
    // Skipping the last SIMD for safety.
    for simdID in 0..<(simdCount - 1) {
      let simdData = debugData[simdID]
      
      for binThreshold in binThresholds {
        let promotedThreshold = SIMD32<UInt16>(
          repeating: UInt16(binThreshold))
        
        var threadMask: SIMD32<UInt16> = .zero
        threadMask.replace(
          with: SIMD32.one, where: simdData .<= promotedThreshold)
        
        let threadCount = threadMask.wrappedSum()
        let simdCount = all(threadMask .> 0) ? UInt16(1) : UInt16(0)
        singleThreadBins[binThreshold] += Int(threadCount)
        entireSIMDBins[binThreshold] += Int(simdCount)
      }
    }
    
    print()
    for binThreshold in binThresholds {
      let cumulative = singleThreadBins[Int(binThreshold)]
      let proportion = Float(cumulative) / Float(currentAtomCount)
      let repr = String(format: "%.3f", proportion)
      print(repr, terminator: ", ")
    }
    print()
    
    for binThreshold in binThresholds {
      let cumulative = entireSIMDBins[Int(binThreshold)]
      let proportion = Float(cumulative) / Float(simdCount)
      let repr = String(format: "%.3f", proportion)
      print(repr, terminator: ", ")
    }
    print()
    
    exit(0)
  }
}

// MARK: - Atoms

extension BVHBuilder {
  func buildSmallPart1_1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 3
    encoder.setBuffer(bvhArguments, offset: 0, index: 0)
    encoder.setBuffer(convertedAtoms, offset: 0, index: 1)
    encoder.setBuffer(relativeOffsetsDebug, offset: 0, index: 2)
    encoder.setBuffer(smallCounterMetadata, offset: 0, index: 3)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart1_1
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: currentAtomCount, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    
  }
  
  func buildSmallPart2_2(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 4
    encoder.setBuffer(bvhArguments, offset: 0, index: 0)
    encoder.setBuffer(convertedAtoms, offset: 0, index: 1)
    encoder.setBuffer(relativeOffsetsDebug, offset: 0, index: 2)
    encoder.setBuffer(smallCounterMetadata, offset: 0, index: 3)
    encoder.setBuffer(smallAtomReferences, offset: 0, index: 4)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart2_2
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: currentAtomCount, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
  }
}

// MARK: - Cells

extension BVHBuilder {
  func buildSmallPart0_0(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    do {
      let allocatedMemory = 0
      let boundingBoxMin = 16
      let boundingBoxMax = 32
      encoder.setBuffer(globalCounters, offset: allocatedMemory, index: 0)
      encoder.setBuffer(globalCounters, offset: boundingBoxMin, index: 1)
      encoder.setBuffer(globalCounters, offset: boundingBoxMax, index: 2)
    }
    
    // Arguments 3 - 4
    encoder.setBuffer(bvhArguments, offset: 0, index: 3)
    encoder.setBuffer(indirectDispatchArguments, offset: 0, index: 4)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart0_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
  }
  
  func buildSmallPart1_0(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 1
    encoder.setBuffer(bvhArguments, offset: 0, index: 0)
    encoder.setBuffer(smallCounterMetadata, offset: 0, index: 1)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart1_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: indirectDispatchArguments,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))
  }
  
  func buildSmallPart2_0(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(globalCounters, offset: 0, index: 0)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart2_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
  }
  
  func buildSmallPart2_1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 3
    encoder.setBuffer(bvhArguments, offset: 0, index: 0)
    encoder.setBuffer(globalCounters, offset: 0, index: 1)
    encoder.setBuffer(smallCounterMetadata, offset: 0, index: 2)
    encoder.setBuffer(smallCellMetadata, offset: 0, index: 3)
    
    // Dispatch
    let pipeline = buildSmallPipelines.buildSmallPart2_1
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      indirectBuffer: indirectDispatchArguments,
      indirectBufferOffset: 0,
      threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))
  }
}
