//
//  AccelerationStructureBuilder.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/21/23.
//

import Metal

struct AccelerationStructureBuilder {
  static let doingCompaction = true
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  
  // Memory objects for rendering.
  var atomBuffers: [MTLBuffer?] = Array(repeating: nil, count: 3)
  var boundingBoxBuffers: [MTLBuffer?] = Array(repeating: nil, count: 3)
  var scratchBuffers: [MTLBuffer?] = Array(repeating: nil, count: 3)
  var accels: [MTLAccelerationStructure?] = Array(repeating: nil, count: 3)
  
  // Keep track of memory sizes for exponential expansion.
  var maxAtomBufferSize: Int = 1 << 10
  var maxBoundingBoxBufferSize: Int = 1 << 10
  var maxScratchBufferSize: Int = 1 << 10
  var maxAccelSize: Int = 1 << 10
  
  // Indices into ring buffers of memory objects.
  var atomBufferIndex: Int = 0 // modulo 3
  var boundingBoxBufferIndex: Int = 0 // modulo 3
  var scratchBufferIndex: Int = 0 // modulo 3, sometimes skips one each frame
  var accelIndex: Int = 0 // modulo 3, sometimes skips one each frame
  
  init(renderer: Renderer) {
    self.device = renderer.device
    self.commandQueue = renderer.commandQueue
  }
}

extension AccelerationStructureBuilder {
  // The entire process of fetching, resizing, and nil-coalescing.
  func cycle(
    from buffers: inout [MTLBuffer?],
    index: inout Int,
    currentSize: inout Int,
    desiredSize: Int
  ) -> MTLBuffer {
    var resource = fetch(from: buffers, size: desiredSize, index: index)
    if resource == nil {
      resource = create(
        currentSize: &currentSize, desiredSize: desiredSize, {
          $0.makeBuffer(length: $1)
        })
    }
    guard let resource else { fatalError("This should never happen.") }
    append(resource, to: &buffers, index: &index)
    return resource
  }
  
  func fetch<T: MTLResource>(
    from buffers: [T?],
    size: Int,
    index: Int
  ) -> T? {
    guard let buffer = buffers[index] else {
      return nil
    }
    if buffer.allocatedSize < size {
      return nil
    }
    return buffer
  }
  
  func create<T: MTLResource>(
    currentSize: inout Int,
    desiredSize: Int,
    _ closure: (MTLDevice, Int) -> T?
  ) -> T {
    while currentSize < desiredSize {
      currentSize = currentSize << 1
    }
    guard let output = closure(self.device, currentSize) else {
      fatalError(
        "Could not create object of type \(T.self) with size \(currentSize).")
    }
    return output
  }
  
  func append<T: MTLResource>(
    _ object: T,
    to buffers: inout [T?],
    index: inout Int
  ) {
    buffers[index] = object
    index = (index + 1) % 3
  }
}

extension AccelerationStructureBuilder {
  mutating func build(atoms: [Atom]) -> MTLAccelerationStructure {
    // Generate or fetch a buffer.
    let atomSize = MemoryLayout<Atom>.stride
    let atomBufferSize = atoms.count * atomSize
    precondition(atomSize == 16, "Unexpected atom size.")
    let atomBuffer = cycle(
      from: &atomBuffers,
      index: &atomBufferIndex,
      currentSize: &maxAtomBufferSize,
      desiredSize: atomBufferSize)
    
    // Write the buffer's contents.
    do {
      let atomsPointer = atomBuffer.contents()
        .assumingMemoryBound(to: Atom.self)
      for (index, atom) in atoms.enumerated() {
        atomsPointer[index] = atom
      }
    }
    
    // Generate or fetch a buffer.
    let boundingBoxSize = MemoryLayout<BoundingBox>.stride
    let boundingBoxBufferSize = atoms.count * boundingBoxSize
    precondition(boundingBoxSize == 24, "Unexpected bounding box size.")
    let boundingBoxBuffer = cycle(
      from: &boundingBoxBuffers,
      index: &boundingBoxBufferIndex,
      currentSize: &maxBoundingBoxBufferSize,
      desiredSize: boundingBoxBufferSize)
    
    // Write the buffer's contents.
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
      
      // Allocate scratch space Metal uses to build the acceleration structure.
      let scratchBuffer = cycle(
        from: &scratchBuffers,
        index: &scratchBufferIndex,
        currentSize: &maxScratchBufferSize,
        desiredSize: 32 + accelSizes.buildScratchBufferSize)
      
      // Allocate an acceleration structure large enough for this descriptor.
      // This method doesn't actually build the acceleration structure, but
      // rather allocates memory.
      let desiredSize = accelSizes.accelerationStructureSize
      var accel = fetch(from: accels, size: desiredSize, index: accelIndex)
      if accel == nil {
        accel = create(
          currentSize: &maxAccelSize, desiredSize: desiredSize, {
            $0.makeAccelerationStructure(size: $1)
          })
      }
      guard var accel else { fatalError("This should never happen.") }
      append(accel, to: &accels, index: &accelIndex)
      
      // Create a command buffer that performs the acceleration structure build.
      let commandBuffer = commandQueue.makeCommandBuffer()!
      
      // Create an acceleration structure command encoder.
      let encoder = commandBuffer.makeAccelerationStructureCommandEncoder()!
      
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
        accel = self.compact(
          scratchBuffer: scratchBuffer, accel: accel, descriptor: accelDesc)
      }
      
      // Return the acceleration structure.
      return accel
    }
  }
  
  mutating func compact(
    scratchBuffer: MTLBuffer,
    accel: MTLAccelerationStructure,
    descriptor: MTLAccelerationStructureDescriptor
  ) -> MTLAccelerationStructure {
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
    append(compactedStructure, to: &accels, index: &accelIndex)
    return compactedStructure
  }
}
