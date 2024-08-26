//
//  BVHBuilder+Prepare.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/20/24.
//

import Metal
import QuartzCore
import simd

struct BVHPreparePipelines {
  var convert: MTLComputePipelineState
  var reduceBoxPart1: MTLComputePipelineState
  var reduceBoxPart2: MTLComputePipelineState
  var setIndirectArguments: MTLComputePipelineState
  
  init(library: MTLLibrary) {
    func createPipeline(name: String) -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        fatalError("Could not create function.")
      }
      let device = library.device
      return try! device.makeComputePipelineState(function: function)
    }
    convert = createPipeline(name: "convert")
    reduceBoxPart1 = createPipeline(name: "reduceBoxPart1")
    reduceBoxPart2 = createPipeline(name: "reduceBoxPart2")
    setIndirectArguments = createPipeline(name: "setIndirectArguments")
  }
}

extension BVHBuilder {
  func prepareBVH(frameID: Int) {
    let copyingTime = copyAtoms()
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encodeConvert(to: encoder)
    
    setBoundingBoxCounters(encoder: encoder)
    reduceBoxPart1(encoder: encoder)
    reduceBoxPart2(encoder: encoder)
    setIndirectArguments(encoder: encoder)
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
        frameReporter.reports[index].copyTime = copyingTime
        frameReporter.reports[index].prepareTime = executionTime
      }
    }
    commandBuffer.commit()
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
    let pipeline = preparePipelines.convert
    encoder.setComputePipelineState(pipeline)
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
      let pipeline = resetMemoryPipelines.resetMemory1D
      encoder.setComputePipelineState(pipeline)
      encoder.dispatchThreads(
        MTLSize(width: 4, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
    
    // Minimum counter: start at +infinity
    fillRegion(startSlotID: 0, value: Int32.max)
    
    // Maximum counter: start at -infinity
    fillRegion(startSlotID: 4, value: Int32.min)
  }
  
  func reduceBoxPart1(encoder: MTLComputeCommandEncoder) {
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
      let pipeline = preparePipelines.reduceBoxPart1
      encoder.setComputePipelineState(pipeline)
      
      let atoms = renderer.argumentContainer.currentAtoms
      let partialCount = (atoms.count + 127) / 128
      encoder.dispatchThreadgroups(
        MTLSize(width: partialCount, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
  
  func reduceBoxPart2(encoder: MTLComputeCommandEncoder) {
    // Argument 0
    do {
      let atoms = renderer.argumentContainer.currentAtoms
      var partialCount = (atoms.count + 127) / 128
      encoder.setBytes(&partialCount, length: 4, index: 0)
    }
    
    // Arguments 1 - 2
    encoder.setBuffer(boundingBoxPartialsBuffer, offset: 0, index: 1)
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 2)
    
    // Dispatch
    do {
      let pipeline = preparePipelines.reduceBoxPart2
      encoder.setComputePipelineState(pipeline)
      
      let atoms = renderer.argumentContainer.currentAtoms
      let partialCount = (atoms.count + 127) / 128
      let threadgroupCount = (partialCount + 127) / 128
      encoder.dispatchThreadgroups(
        MTLSize(width: threadgroupCount, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    }
  }
  
  func setIndirectArguments(encoder: MTLComputeCommandEncoder) {
    // Arguments 0 - 1
    encoder.setBuffer(globalAtomicCounters, offset: 0, index: 0)
    encoder.setBuffer(globalAtomicCounters, offset: 16, index: 1)
    
    // Arguments 2 - 3
    encoder.setBuffer(bvhArgumentsBuffer, offset: 0, index: 2)
    encoder.setBuffer(smallCellDispatchArguments128x1x1, offset: 0, index: 3)
    encoder.setBuffer(smallCellDispatchArguments8x8x8, offset: 0, index: 4)
    
    // Dispatch
    let pipeline = preparePipelines.setIndirectArguments
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
  }
}
