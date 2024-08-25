//
//  BVHBuilder+Preprocess.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/20/24.
//

import Metal
import QuartzCore
import simd

extension BVHBuilder {
  func prepareBVH(frameID: Int) {
    let atoms = renderer.argumentContainer.currentAtoms
    
    let copyingStart = CACurrentMediaTime()
    do {
      let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
      let originalAtomsBuffer = originalAtomsBuffers[tripleIndex]
      memcpy(originalAtomsBuffer.contents(), atoms, atoms.count * 16)
    }
    let copyingEnd = CACurrentMediaTime()
    
    let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encodePreprocess(to: encoder)
    encoder.endEncoding()
    
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let executionTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
      self.frameReportQueue.sync {
        for index in self.frameReports.indices.reversed() {
          guard self.frameReports[index].frameID == frameID else {
            continue
          }
          self.frameReports[index].copyingTime = copyingEnd - copyingStart
          self.frameReports[index].preprocessingTimeGPU = executionTime
          break
        }
      }
    }
    commandBuffer.commit()
  }
}

extension BVHBuilder {
  func encodePreprocess(to encoder: MTLComputeCommandEncoder) {
    let atoms = renderer.argumentContainer.currentAtoms
    
    // Argument 0
    do {
      let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
      let originalAtomsBuffer = originalAtomsBuffers[tripleIndex]
      encoder.setBuffer(originalAtomsBuffer, offset: 0, index: 0)
    }
    
    // Arguments 1 - 2
    do {
      renderer.atomRadii.withUnsafeBufferPointer {
        let length = $0.count * 4
        encoder.setBytes($0.baseAddress!, length: length, index: 1)
      }
      encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 2)
    }
    
    // Dispatch
    do {
      encoder.setComputePipelineState(preprocessPipeline)
      encoder.dispatchThreads(
        MTLSizeMake(atoms.count, 1, 1),
        threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    }
  }
}
