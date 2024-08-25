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
  func preprocessAtoms(commandQueue: MTLCommandQueue, frameID: Int) {
    let atoms = renderer.argumentContainer.currentAtoms
    
    // Start the encoder.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(preprocessPipeline)
    
    // Argument 0
    let copyingStart = CACurrentMediaTime()
    do {
      let tripleIndex = renderer.argumentContainer.tripleBufferIndex()
      let originalAtomsBuffer = originalAtomsBuffers[tripleIndex]
      memcpy(originalAtomsBuffer.contents(), atoms, atoms.count * 16)
      encoder.setBuffer(originalAtomsBuffer, offset: 0, index: 0)
    }
    let copyingEnd = CACurrentMediaTime()
    
    // Argument 1
    do {
      var atomRadii = renderer.atomRadii
      atomRadii.withUnsafeBufferPointer {
        let length = $0.count * 4
        encoder.setBytes($0.baseAddress!, length: length, index: 1)
      }
    }
    
    // Argument 2
    do {
      encoder.setBuffer(convertedAtomsBuffer, offset: 0, index: 2)
    }
    
    // Finish the encoder.
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    encoder.endEncoding()
    
    // Add the completed handler.
    let copyingTime = copyingEnd - copyingStart
    commandBuffer.addCompletedHandler { [self] commandBuffer in
      let executionTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
      self.frameReportQueue.sync {
        for index in self.frameReports.indices.reversed() {
          guard self.frameReports[index].frameID == frameID else {
            continue
          }
          self.frameReports[index].copyingTime = copyingTime
          self.frameReports[index].preprocessingTimeGPU = executionTime
          break
        }
      }
    }
    commandBuffer.commit()
  }
}
