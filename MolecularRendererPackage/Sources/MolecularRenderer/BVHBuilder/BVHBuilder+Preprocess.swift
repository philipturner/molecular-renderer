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
      let quantized = quantize(atoms: atoms)
      
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
  
  func quantize(atoms: [SIMD4<Float>]) -> [UInt64] {
    var output = [UInt64](repeating: .zero, count: atoms.count)
    for atomID in atoms.indices {
      var scaled = atoms[atomID]
      scaled *= SIMD4(1024, 1024, 1024, 1)
      
      #if arch(arm64) || arch(arm64e)
      // vcvtnq_u32_f32 - round to nearest or even
      // vcvtmq_u32_f32 - round toward minus infinity
      // vcvtpq_u32_f32 - round toward plus infinity
      // vcvtaq_u32_f32 - round away from zero
      // vcvtq_n_u32_f32 - round to zero
      let quantized: SIMD4<UInt32> = vcvtnq_u32_f32(scaled)
      #else
      let rounded = scaled.rounded(.toNearestOrEven)
      let quantized = SIMD4<Int32>(
        Int32(scaled.x),
        Int32(scaled.y),
        Int32(scaled.z),
        Int32(scaled.w))
      fatalError()
      #endif
      
      let intValue = unsafeBitCast(quantized, to: SIMD2<UInt64>.self)[0]
      output[atomID] = unsafeBitCast(intValue, to: UInt64.self)
    }
    
    // TODO: Add a second kernel that effectively dequantizes the atoms.
    return output
  }
}
