//
//  BVHBuilder+Preprocess.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/20/24.
//

import Metal
import QuartzCore

extension BVHBuilder {
  func preprocessAtoms(commandQueue: MTLCommandQueue, frameID: Int) {
    let atomsBuffer = allocate(
      &denseGridAtoms[ringIndex],
      desiredElements: atoms.count,
      bytesPerElement: 16)
    
    let copyingStart = CACurrentMediaTime()
    memcpy(atomsBuffer.contents(), atoms, atoms.count * 16)
    let copyingEnd = CACurrentMediaTime()
    
    // Start the encoder.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    
    // Encode the preprocessing command.
    encoder.setComputePipelineState(preprocessPipeline)
    atomStyles.withUnsafeBufferPointer {
      let length = $0.count * 8
      encoder.setBytes($0.baseAddress!, length: length, index: 0)
    }
    encoder.setBuffer(atomsBuffer, offset: 0, index: 1)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    
    // Finish the encoder.
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
