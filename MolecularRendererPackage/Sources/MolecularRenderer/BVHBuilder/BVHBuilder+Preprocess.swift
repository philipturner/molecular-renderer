//
//  BVHBuilder+Preprocess.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/20/24.
//

import Metal
import QuartzCore

extension BVHBuilder {
  static func createPreprocessFunction(
    device: MTLDevice,
    library: MTLLibrary
  ) -> MTLComputePipelineState {
    let preprocessFunction = library.makeFunction(name: "preprocess")!
    return try! device.makeComputePipelineState(
      function: preprocessFunction)
  }
}

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
      let beforeAtomsBuffer = denseGridAtoms[tripleIndex]
      memcpy(beforeAtomsBuffer.contents(), atoms, atoms.count * 16)
      encoder.setBuffer(beforeAtomsBuffer, offset: 0, index: 0)
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
      let doubleIndex = renderer.argumentContainer.doubleBufferIndex()
      let afterAtomsBuffer = newAtomsBuffers[doubleIndex]
      encoder.setBuffer(afterAtomsBuffer, offset: 0, index: 2)
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
