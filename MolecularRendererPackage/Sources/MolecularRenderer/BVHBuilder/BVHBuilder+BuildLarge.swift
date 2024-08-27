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
    //clearLargeCellMetadata(encoder: encoder)
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
    
#if false
    commandBuffer.waitUntilCompleted()
    
    let metadata = largeCellMetadata.contents()
      .assumingMemoryBound(to: UInt32.self)
    print()
    print(metadata[0])
    print(metadata[4 * 8 * 9 + 4 * 9 + 4])
    print(metadata[8 * 8 * 9 - 1])
    print(metadata[8 * 8 * 9])
    print()
    
    var referenceCount: Int = .zero
    for voxelID in 0..<largeCellMetadata.length / 4 {
      let voxelAtomCount = metadata[voxelID]
      referenceCount += Int(voxelAtomCount)
    }
    print()
    print(referenceCount)
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
    // Argument 0
    do {
      let atoms = renderer.argumentContainer.currentAtoms
      var atomCount = UInt32(atoms.count)
      encoder.setBytes(&atomCount, length: 4, index: 0)
    }
    
    // Arguments 1 - 3
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 1)
    encoder.setBuffer(largeCellMetadata, offset: 0, index: 2)
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 3)
    
    // Dispatch
    do {
      let pipeline = buildLargePipelines.buildLargePart1
      encoder.setComputePipelineState(pipeline)
      
      let atoms = renderer.argumentContainer.currentAtoms
      let reversedBits: Int = 0
      
      var atomsRounded = atoms.count
      atomsRounded += (1 << reversedBits) - 1
      atomsRounded /= 1 << reversedBits
      atomsRounded *= 1 << reversedBits
      encoder.dispatchThreads(
        MTLSize(width: atomsRounded, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
}
