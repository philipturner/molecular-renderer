//
//  BVHBuilder+BuildLarge.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/27/24.
//

import Metal

struct BVHBuildLargePipelines {
  var buildLargePart1_1: MTLComputePipelineState
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
    buildLargePart1_1 = createPipeline(name: "buildLargePart1_1")
    buildLargePart2_0 = createPipeline(name: "buildLargePart2_0")
    buildLargePart2_1 = createPipeline(name: "buildLargePart2_1")
  }
}

extension BVHBuilder {
  func buildLargeBVH(frameID: Int) {
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    buildLargePart1_1(encoder: encoder)
    
    buildLargePart1_0(encoder: encoder)
    buildLargePart1_1(encoder: encoder)
    buildLargePart2_0(encoder: encoder)
    buildLargePart2_1(encoder: encoder)
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
        frameReporter.reports[index].buildLargeTime = executionTime
      }
    }
    commandBuffer.commit()
    
    #if true
    commandBuffer.waitUntilCompleted()
    
    let metadata = largeInputMetadata.contents()
      .assumingMemoryBound(to: UInt32.self)
    
    var largeReferenceCount: Int = .zero
    var smallReferenceCount: Int = .zero
    for cellID in 0..<(largeInputMetadata.length / 4) {
      let word = metadata[cellID]
      largeReferenceCount += Int(word) & Int(1 << 14 - 1)
      smallReferenceCount += Int(word) >> 14;
    }
    
    print()
    print(largeReferenceCount)
    print(smallReferenceCount)
    print()
    
    // C(100)
    // 2.00 nm - 783476
    // 0.25 nm - 5118550
    //
    // SiC(100)
    // 2.00 nm - 805380
    // 0.25 nm - 6127888
    //
    // Si(100)
    // 2.00 nm - 844074
    // 0.25 nm - 7080208
    //
    // Au(100)
    // 2.00 nm - 499950
    // 0.25 nm - 6406456
    //
    // C(100) Bounding Box
    // minimum - [0, -8, -16]
    // maximum - [16, 8, 2]
    
    let counters = globalAtomicCounters.contents()
      .assumingMemoryBound(to: Int32.self)
    
    print()
    print(counters[0])
    print(counters[1])
    print(counters[2])
    print(counters[3])
    print(counters[4])
    print(counters[5])
    print(counters[6])
    print(counters[7])
    print(counters[8])
    print(counters[9])
    print(counters[10])
    print(counters[11])
    print()
    
    exit(0)
    #endif
  }
}

extension BVHBuilder {
  func buildLargePart1_0(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(largeInputMetadata, offset: 0, index: 0)
    
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
    // Arguments 0 - 1
    encoder.setBuffer(largeInputMetadata, offset: 0, index: 0)
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 1)
    
    // Arguments 2 - 3
    do {
      let offset1 = 0
      let offset2 = relativeOffsetsBuffer.length / 2
      encoder.setBuffer(relativeOffsetsBuffer, offset: offset1, index: 2)
      encoder.setBuffer(relativeOffsetsBuffer, offset: offset2, index: 3)
    }
    
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
    // Argument 0
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 0)
    
    // Dispatch
    let pipeline = buildLargePipelines.buildLargePart2_0
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
  }
  
  func buildLargePart2_1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 1
    encoder.setBuffer(largeInputMetadata, offset: 0, index: 0)
    encoder.setBuffer(largeOutputMetadata, offset: 0, index: 1)
    
    // Arguments 2 - 6
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 2)
    encoder.setBuffer(globalAtomicCounters, offset: 4, index: 3)
    encoder.setBuffer(globalAtomicCounters, offset: 8, index: 4)
    encoder.setBuffer(globalAtomicCounters, offset: 16, index: 5)
    encoder.setBuffer(globalAtomicCounters, offset: 32, index: 6)
    
    // Dispatch
    let pipeline = buildLargePipelines.buildLargePart2_1
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreadgroups(
      MTLSize(width: 64 * 64 * 64 / 64, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
  }
}
