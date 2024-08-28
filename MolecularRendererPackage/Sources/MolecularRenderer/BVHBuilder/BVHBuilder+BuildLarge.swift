//
//  BVHBuilder+BuildLarge.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/27/24.
//

import Metal

struct BVHBuildLargePipelines {
  var buildLargePart1: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    buildLargePart1 = createPipeline(name: "buildLargePart1")
  }
}

extension BVHBuilder {
  func buildLargeBVH(frameID: Int) {
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    clearLargeCellMetadata(encoder: encoder)
    
    buildLargePart1(encoder: encoder)
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
    
    let metadata = largeCellMetadata.contents()
      .assumingMemoryBound(to: UInt32.self)
    
    var largeReferenceCount: Int = .zero
    var smallReferenceCount: Int = .zero
    for cellID in 0..<(largeCellMetadata.length / 4) {
      let word = metadata[cellID]
      largeReferenceCount += Int(word) & Int(1 << 14 - 1)
      smallReferenceCount += Int(word) >> 14;
    }
    
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
    print()
    print(largeReferenceCount)
    print(smallReferenceCount)
    print()
    
    let rawPointer1 = relativeOffsetsBuffer.contents()
    let rawPointer2 = rawPointer1 + relativeOffsetsBuffer.length / 2
    let offsets1 = rawPointer1.assumingMemoryBound(to: SIMD4<UInt16>.self)
    let offsets2 = rawPointer2.assumingMemoryBound(to: SIMD4<UInt16>.self)
    
    /*
     0 | SIMD8<UInt16>(0, 16383, 16383, 16383, 16383, 16383, 16383, 16383)
     1 | SIMD8<UInt16>(0, 16383, 16383, 16383, 16383, 16383, 16383, 16383)
     2 | SIMD8<UInt16>(0, 16383, 24, 16383, 16383, 16383, 16383, 16383)
     3 | SIMD8<UInt16>(0, 16383, 17, 16383, 16383, 16383, 16383, 16383)
     4 | SIMD8<UInt16>(0, 16383, 29, 16383, 16383, 16383, 16383, 16383)
     5 | SIMD8<UInt16>(0, 16383, 22, 16383, 16383, 16383, 16383, 16383)
     6 | SIMD8<UInt16>(0, 16383, 16383, 16383, 16383, 16383, 16383, 16383)
     7 | SIMD8<UInt16>(0, 16383, 16383, 16383, 16383, 16383, 16383, 16383)
     8 | SIMD8<UInt16>(1, 16383, 16383, 16383, 16383, 16383, 16383, 16383)
     9 | SIMD8<UInt16>(1, 16383, 16383, 16383, 16383, 16383, 16383, 16383)
     10 | SIMD8<UInt16>(1, 16383, 25, 16383, 16383, 16383, 16383, 16383)
     11 | SIMD8<UInt16>(1, 16383, 18, 16383, 16383, 16383, 16383, 16383)
     12 | SIMD8<UInt16>(1, 16383, 30, 16383, 16383, 16383, 16383, 16383)
     13 | SIMD8<UInt16>(1, 16383, 23, 16383, 16383, 16383, 16383, 16383)
     14 | SIMD8<UInt16>(1, 16383, 16383, 16383, 16383, 16383, 16383, 16383)
     15 | SIMD8<UInt16>(1, 16383, 16383, 16383, 16383, 16383, 16383, 16383)
     */
    
    print()
    for offsetID in 0..<16 {
      print(offsetID, "|", offsets1[offsetID], offsets2[offsetID])
    }
    print()
    
    exit(0)
    #endif
  }
}

extension BVHBuilder {
  func clearLargeCellMetadata(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    encoder.setBuffer(largeCellMetadata, offset: 0, index: 0)
    
    // Argument 1
    var pattern: UInt32 = .zero
    encoder.setBytes(&pattern, length: 4, index: 1)
    
    // Dispatch
    do {
      let pipeline = resetMemoryPipelines.resetMemory1D
      encoder.setComputePipelineState(pipeline)
      
      let largeCellCount = largeCellMetadata.length / 4
      encoder.dispatchThreadgroups(
        MTLSize(width: largeCellCount / 128, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
  
  func buildLargePart1(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 2
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 0)
    encoder.setBuffer(largeCellMetadata, offset: 0, index: 1)
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 2)
    
    // Arguments 3 - 4
    do {
      let offset1 = 0
      let offset2 = relativeOffsetsBuffer.length / 2
      encoder.setBuffer(relativeOffsetsBuffer, offset: offset1, index: 3)
      encoder.setBuffer(relativeOffsetsBuffer, offset: offset2, index: 4)
    }
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart1
      encoder.setComputePipelineState(pipeline)
      
      let atoms = renderer.argumentContainer.currentAtoms
      encoder.dispatchThreads(
        MTLSize(width: atoms.count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
}
