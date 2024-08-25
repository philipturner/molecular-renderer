//
//  BVHBuilder+Update.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

extension BVHBuilder {
  func updateResources() {
    // Generate or fetch a buffer.
    let atomBufferSize = atoms.count * 16
    let motionVectorBufferSize = motionVectors.count * 16
    
    let ringIndex = renderer.argumentContainer.tripleBufferIndex()
    let motionVectorBuffer = motionVectorBuffers[ringIndex]
    
    // Write the motion vector buffer's contents.
    let motionVectorsPointer = motionVectorBuffer.contents()
      .assumingMemoryBound(to: SIMD3<Float>.self)
    for (index, motionVector) in motionVectors.enumerated() {
      motionVectorsPointer[index] = motionVector
    }
  }
}
