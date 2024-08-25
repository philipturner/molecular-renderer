//
//  BVHBuilder+Prepare.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/20/24.
//

import Metal
import QuartzCore
import simd

extension BVHBuilder {
  func prepareBVH(frameID: Int) {
    let preprocessingTimeCPU = reduceAndAssignBB()
    let copyingTime = copyAtoms()
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encodeConvert(to: encoder)
    setBoundingBoxCounters(encoder: encoder)
    reduceBoundingBox(encoder: encoder)
    encoder.endEncoding()
    
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let frameReporter = self.renderer.frameReporter!
      frameReporter.queue.sync {
        let index = frameReporter.index(of: frameID)
        guard let index else {
          return
        }
        
        let executionTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        frameReporter.reports[index].reduceBBTime = preprocessingTimeCPU
        frameReporter.reports[index].copyTime = copyingTime
        frameReporter.reports[index].prepareTime = executionTime
      }
    }
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    let partials = boundingBoxPartialsBuffer.contents()
      .assumingMemoryBound(to: SIMD3<Int32>.self)
    let atoms = renderer.argumentContainer.currentAtoms
    let groupCount = (atoms.count + 127) / 128
    
    for groupID in 0..<groupCount {
      let minimum = partials[2 * groupID + 0]
      let maximum = partials[2 * groupID + 1]
      print("group \(groupID) | ", minimum, maximum)
    }
    
    print()
    print("true bounding box:")
    print(worldMinimum)
    print(worldMaximum)
    
    exit(0)
  }
}

extension BVHBuilder {
  // Run and time the bounding box construction.
  func reduceAndAssignBB() -> Double {
    let preprocessingStart = CACurrentMediaTime()
    (worldMinimum, worldMaximum) = reduceBoundingBox()
    let preprocessingEnd = CACurrentMediaTime()
    
    return preprocessingEnd - preprocessingStart
  }
  
  // Run and time the copying into the GPU buffer.
  func copyAtoms() -> Double {
    let atoms = renderer.argumentContainer.currentAtoms
    let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
    let originalAtomsBuffer = originalAtomsBuffers[tripleIndex]
    
    let copyingStart = CACurrentMediaTime()
    memcpy(originalAtomsBuffer.contents(), atoms, atoms.count * 16)
    let copyingEnd = CACurrentMediaTime()
    
    return copyingEnd - copyingStart
  }
}

extension BVHBuilder {
  func encodeConvert(to encoder: MTLComputeCommandEncoder) {
    // Argument 0
    do {
      let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
      let originalAtomsBuffer = originalAtomsBuffers[tripleIndex]
      encoder.setBuffer(originalAtomsBuffer, offset: 0, index: 0)
    }
    
    // Argument 1
    renderer.atomRadii.withUnsafeBufferPointer {
      let length = $0.count * 4
      encoder.setBytes($0.baseAddress!, length: length, index: 1)
    }
    
    // Argument 2
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 2)
    
    // Dispatch
    let atoms = renderer.argumentContainer.currentAtoms
    encoder.setComputePipelineState(convertPipeline)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  func setBoundingBoxCounters(encoder: MTLComputeCommandEncoder) {
    func fillRegion(startSlotID: Int, value: Int32) {
      // Argument 0
      let offset = startSlotID * 4
      encoder.setBuffer(globalAtomicCounters, offset: offset, index: 0)
      
      // Argument 1
      var pattern: Int32 = value
      encoder.setBytes(&pattern, length: 4, index: 1)
      
      // Dispatch four threads, to fill four slots.
      encoder.setComputePipelineState(resetMemory1DPipeline)
      encoder.dispatchThreads(
        MTLSize(width: 4, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
    
    // Minimum counter: start at +infinity
    fillRegion(startSlotID: 0, value: Int32.max)
    
    // Maximum counter: start at -infinity
    fillRegion(startSlotID: 4, value: Int32.min)
  }
  
  func reduceBoundingBox(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    do {
      let atoms = renderer.argumentContainer.currentAtoms
      var atomCount = UInt32(atoms.count)
      encoder.setBytes(&atomCount, length: 4, index: 0)
    }
    
    // Arguments 1 - 2
    encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 1)
    encoder.setBuffer(boundingBoxPartialsBuffer, offset: 0, index: 2)
    
    // Dispatch
    do {
      let atoms = renderer.argumentContainer.currentAtoms
      let threadgroupCount = (atoms.count + 127) / 128
      encoder.setComputePipelineState(reduceBBPart1Pipeline)
      encoder.dispatchThreadgroups(
        MTLSize(width: threadgroupCount, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
}
