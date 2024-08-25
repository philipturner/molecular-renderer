//
//  BVHBuilder+Update.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

extension BVHBuilder {
  func updateResources() {
    ringIndex = (ringIndex + 1) % 3
    
    // Generate or fetch a buffer.
    let atomBufferSize = atoms.count * 16
    let motionVectorBufferSize = motionVectors.count * 16
    let motionVectorBuffer = cycle(
      from: &motionVectorBuffers,
      index: ringIndex,
      desiredSize: motionVectorBufferSize,
      name: "MotionVectors")
    
    // Write the motion vector buffer's contents.
    let motionVectorsPointer = motionVectorBuffer.contents()
      .assumingMemoryBound(to: SIMD3<Float>.self)
    for (index, motionVector) in motionVectors.enumerated() {
      motionVectorsPointer[index] = motionVector
    }
  }
}
