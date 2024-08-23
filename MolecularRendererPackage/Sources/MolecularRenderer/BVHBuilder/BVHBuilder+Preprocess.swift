//
//  BVHBuilder+Preprocess.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/20/24.
//

import Metal
import QuartzCore

// Encode the "reduced complexity stepping stone"
//
// ## Step 1
//
// preallocate an array of 32-bit voxel data
//
// ## Step 2
//
// overwrite the 32-bit voxel data with zero (memset)
//
// ## Step 3
//
// bind memory allocations: 1, 2, 4
// bind the pipeline state object:
//
// ```
// read atom (1)
// read exact atomic radius (2)
// locate closest voxel
// atomically increment the voxel's counter (4)
// ```
//
// dispatch 'atoms.count' threads
//
// ## Step 4
//
// stall and dissect the outcome on the CPU
// - bounding box: compare against box from multicore CPU kernel
// - reference count: compare against atom count
// crash the program

extension BVHBuilder {
  static func createVoxelDataBuffer(
    device: MTLDevice
  ) -> MTLBuffer {
    // How many bytes is the buffer?
    // (128 nm / 2 nm)^3 = 262,144 voxels
    // 4 bytes per voxel
    let bufferSize: Int = 1024 * 1024
    return device.makeBuffer(length: bufferSize)!
  }
  
  func bindAtomStyles(to encoder: MTLComputeCommandEncoder) {
    atomStyles.withUnsafeBufferPointer {
      let length = $0.count * 8
      encoder.setBytes($0.baseAddress!, length: length, index: 2)
    }
  }
}

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
    
    // Encode the memset command.
    encoder.setComputePipelineState(memsetPipeline)
    encoder.setBuffer(voxelDataBuffer, offset: 0, index: 0)
    encoder.dispatchThreads(
      MTLSize(width: 256 * 1024, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
    
    // Encode the preprocessing command.
    encoder.setComputePipelineState(preprocessPipeline)
    encoder.setBuffer(atomsBuffer, offset: 0, index: 1)
    bindAtomStyles(to: encoder)
    encoder.setBuffer(voxelDataBuffer, offset: 0, index: 4)
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
    
    #if true
    
    // Stall on the CPU.
    commandBuffer.waitUntilCompleted()
    let voxelDataPointer = voxelDataBuffer.contents()
      .assumingMemoryBound(to: UInt32.self)
    
    // Reduce the bounding box.
    do {
      var minimum: SIMD3<Float> = .zero
      var maximum: SIMD3<Float> = .zero
      var referenceCount: Int = .zero
      for z in 0..<64 {
        for y in 0..<64 {
          for x in 0..<64 {
            let address = z * (64 * 64) + y * 64 + x
            let voxelDatum = voxelDataPointer[address]
            guard voxelDatum > 0 else {
              continue
            }
            
            let coordinates = SIMD3(x, y, z)
            let lowerCorner = 2 * SIMD3<Float>(coordinates) - 64
            let upperCorner = lowerCorner + 2
            
            minimum.replace(
              with: lowerCorner, where: lowerCorner .< minimum)
            maximum.replace(
              with: upperCorner, where: upperCorner .> maximum)
            referenceCount += Int(voxelDatum)
          }
        }
      }
      
      print()
      print(SIMD3<Int16>(-2, -8, -16))
      print(SIMD3<Int16>(-2, -8, -16) &+ SIMD3<Int16>(18, 16, 18))
      print(atoms.count)
      print()
      print(minimum)
      print(maximum)
      print(referenceCount)
      print()
      
      /*
       expected:
       SIMD3<Int16>(-2, -8, -16)
       SIMD3<Int16>(16, 8, 2)
       521721
       
       actual:
       SIMD3<Float>(0.0, -8.0, -16.0)
       SIMD3<Float>(16.0, 8.0, 2.0)
       521721
       
       bounding box:
       -2 <= 0.0 < 16.0 <= 16
       -8 <= -8.0 < 8.0 <= 8
       -16 <= -16.0 < 2.0 <= 2
       
       atom count:
       521721 == 521721
       */
    }
    
    // Crash the program.
    exit(0)
    
    #endif
  }
}
