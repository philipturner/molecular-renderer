//
//  AccelerationStructureBuilder.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/21/23.
//

import Metal

struct AccelerationStructureBuilder {
  // TODO: Functionality for expanding accel buffers by powers of 2. Use an
  // integer that you keep left shifting by 1 in a while loop.
  var cpuBufferIndex: Int = 0 // modulo 3
  var accelBufferIndex: Int = 0 // modulo 3, sometimes skips one each frame
  static let doingCompaction = false
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  
  // Memory objects for rendering.
  // TODO: Triple-buffer the CPU buffers and accel, enable
  // compacting them without allocating new memory each frame.
  var atomBuffer: MTLBuffer!
  var boundingBoxBuffer: MTLBuffer!
  var scratchBuffer: MTLBuffer!
  var accel: MTLAccelerationStructure!
  
  init(renderer: Renderer) {
    self.device = renderer.device
    self.commandQueue = renderer.commandQueue
  }
}

extension AccelerationStructureBuilder {
  mutating func build(atoms: [Atom]) {
    let atomSize = MemoryLayout<Atom>.stride
    let atomBufferSize = atoms.count * atomSize
    precondition(atomSize == 16, "Unexpected atom size.")
    self.atomBuffer = device.makeBuffer(length: atomBufferSize)!
    
    do {
      let atomsPointer = atomBuffer.contents()
        .assumingMemoryBound(to: Atom.self)
      for (index, atom) in atoms.enumerated() {
        atomsPointer[index] = atom
      }
    }
    
    let boundingBoxSize = MemoryLayout<BoundingBox>.stride
    let boundingBoxBufferSize = atoms.count * boundingBoxSize
    precondition(boundingBoxSize == 24, "Unexpected bounding box size.")
    self.boundingBoxBuffer = device.makeBuffer(length: boundingBoxBufferSize)!
    
    do {
      let boundingBoxesPointer = boundingBoxBuffer.contents()
        .assumingMemoryBound(to: BoundingBox.self)
      for (index, atom) in atoms.enumerated() {
        let boundingBox = atom.boundingBox
        boundingBoxesPointer[index] = boundingBox
      }
    }
    
    let geometryDesc = MTLAccelerationStructureBoundingBoxGeometryDescriptor()
    geometryDesc.primitiveDataBuffer = atomBuffer
    geometryDesc.primitiveDataStride = atomSize
    geometryDesc.primitiveDataBufferOffset = 0
    geometryDesc.primitiveDataElementSize = atomSize
    geometryDesc.boundingBoxCount = atoms.count
    geometryDesc.boundingBoxStride = boundingBoxSize
    geometryDesc.boundingBoxBufferOffset = 0
    geometryDesc.boundingBoxBuffer = boundingBoxBuffer
    
    let accelDesc = MTLPrimitiveAccelerationStructureDescriptor()
    accelDesc.geometryDescriptors = [geometryDesc]
    do {
      // Copied from Apple's ray tracing sample code:
      // https://developer.apple.com/documentation/metal/metal_sample_code_library/control_the_ray_tracing_process_using_intersection_queries
      
      // Query for the sizes needed to store and build the acceleration
      // structure.
      let accelSizes = device.accelerationStructureSizes(descriptor: accelDesc)
      
      // Allocate an acceleration structure large enough for this descriptor.
      // This method doesn't actually build the acceleration structure, but
      // rather allocates memory.
      self.accel = device.makeAccelerationStructure(
        size: accelSizes.accelerationStructureSize)!
      
      // Allocate scratch space Metal uses to build the acceleration structure.
      self.scratchBuffer = device.makeBuffer(
        length: 32 + accelSizes.buildScratchBufferSize)!
      
      // Create a command buffer that performs the acceleration structure build.
      var commandBuffer = commandQueue.makeCommandBuffer()!
      
      // Create an acceleration structure command encoder.
      var encoder = commandBuffer.makeAccelerationStructureCommandEncoder()!
      
      // Schedule the actual acceleration structure build.
      encoder.build(
        accelerationStructure: accel, descriptor: accelDesc,
        scratchBuffer: scratchBuffer, scratchBufferOffset: 32)
      
      // Compute and write the compacted acceleration structure size into the
      // buffer.
      if AccelerationStructureBuilder.doingCompaction {
        encoder.writeCompactedSize(
          accelerationStructure: accel, buffer: scratchBuffer, offset: 0,
          sizeDataType: .uint)
      }
      
      // End encoding, and commit the command buffer so the GPU can start
      // building the acceleration structure.
      encoder.endEncoding()
      commandBuffer.commit()
      
      if AccelerationStructureBuilder.doingCompaction {
        commandBuffer.waitUntilCompleted()
        self.compact(descriptor: accelDesc)
      }
    }
  }
  
  mutating func compact(descriptor: MTLAccelerationStructureDescriptor) {
    let compactedSize = scratchBuffer.contents()
      .assumingMemoryBound(to: UInt32.self).pointee
    let compactedStructure = device
      .makeAccelerationStructure(size: Int(compactedSize))!
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeAccelerationStructureCommandEncoder()!
    
    // Encode the command to copy and compact the acceleration structure into
    // the smaller acceleration structure.
    encoder.copyAndCompact(
      sourceAccelerationStructure: accel,
      destinationAccelerationStructure: compactedStructure)
    
    encoder.endEncoding()
    commandBuffer.commit()
    
    // Re-assign the current acceleration structure to the compacted one.
    self.accel = compactedStructure
  }
}
