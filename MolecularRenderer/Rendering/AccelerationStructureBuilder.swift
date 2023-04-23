//
//  AccelerationStructureBuilder.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/21/23.
//

import Metal

// Partially sourced from:
// https://developer.apple.com/documentation/metal/metal_sample_code_library/control_the_ray_tracing_process_using_intersection_queries

struct AccelerationStructureBuilder {
  // Compaction saves a lot of memory, but doesn't really change whether it is
  // aligned along cache lines. If anything, it only increases the memory
  // because we now have two scratch buffers.
  static let doingCompaction = false
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  
  // Triple buffer because the CPU writes to these.
  var atomBuffers: [MTLBuffer?] = Array(repeating: nil, count: 3)
  var boundingBoxBuffers: [MTLBuffer?] = Array(repeating: nil, count: 3)
  
  // Double buffer the accels to remove dependencies between frames.
  // If compaction is enabled, some dependencies will not be removed.
  var scratchBuffers: [MTLBuffer?] = Array(repeating: nil, count: 2)
  var accels: [MTLAccelerationStructure?] = Array(repeating: nil, count: 2)
  
  // Keep track of memory sizes for exponential expansion.
  var maxAtomBufferSize: Int = 1 << 10
  var maxBoundingBoxBufferSize: Int = 1 << 10
  var maxScratchBufferSize: Int = 1 << 10
  var maxAccelSize: Int = 1 << 10
  
  // Indices into ring buffers of memory objects.
  var atomBufferIndex: Int = 0 // modulo 3
  var boundingBoxBufferIndex: Int = 0 // modulo 3
  var scratchBufferIndex: Int = 0 // modulo 2
  var accelIndex: Int = 0 // modulo 2
  
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
    desiredSize: Int,
    name: String
  ) -> MTLBuffer {
    var resource = fetch(from: buffers, size: desiredSize, index: index)
    if resource == nil {
      resource = create(
        currentSize: &currentSize, desiredSize: desiredSize, {
          $0.makeBuffer(length: $1)
        })
      resource!.label = name
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
    index = (index + 1) % buffers.count
  }
}

extension AccelerationStructureBuilder {
  mutating func build(atoms: [Atom], commandBuffer: MTLCommandBuffer) -> MTLAccelerationStructure {
    // Generate or fetch a buffer.
    let atomSize = MemoryLayout<Atom>.stride
    let atomBufferSize = atoms.count * atomSize
    precondition(atomSize == 16, "Unexpected atom size.")
    let atomBuffer = cycle(
      from: &atomBuffers,
      index: &atomBufferIndex,
      currentSize: &maxAtomBufferSize,
      desiredSize: atomBufferSize,
      name: "Atoms")
    
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
      desiredSize: boundingBoxBufferSize,
      name: "Bounding Boxes")
    
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
    
    // The intersection function is going to be extremely expensive. Set this
    // flag even before we migrate to tile-based intersections, to see the
    // performance impact.
    // TODO: Measure how much this impacts the accel construction pass and the
    // render pass. If rendering doesn't require many intersections, this may
    // harm performance.
    geometryDesc.allowDuplicateIntersectionFunctionInvocation = false
    
    let accelDesc = MTLPrimitiveAccelerationStructureDescriptor()
    accelDesc.geometryDescriptors = [geometryDesc]
    
    // Query for the sizes needed to store and build the acceleration structure.
    let accelSizes = device.accelerationStructureSizes(descriptor: accelDesc)
    
    // Allocate scratch space Metal uses to build the acceleration structure.
    let scratchBuffer = cycle(
      from: &scratchBuffers,
      index: &scratchBufferIndex,
      currentSize: &maxScratchBufferSize,
      desiredSize: 32 + accelSizes.buildScratchBufferSize,
      name: "Scratch Space")
    
    // Allocate an acceleration structure large enough for this descriptor. This
    // method doesn't actually build the acceleration structure, but rather
    // allocates memory.
    let desiredSize = accelSizes.accelerationStructureSize
    var accel = fetch(from: accels, size: desiredSize, index: accelIndex)
    if accel == nil {
      accel = create(
        currentSize: &maxAccelSize, desiredSize: desiredSize, {
          $0.makeAccelerationStructure(size: $1)
        })
      accel!.label = "Molecule"
    }
    guard var accel else { fatalError("This should never happen.") }
    append(accel, to: &accels, index: &accelIndex)
    
    // Create an acceleration structure command encoder.
    let encoder = commandBuffer.makeAccelerationStructureCommandEncoder()!
    
    // Schedule the actual acceleration structure build.
    encoder.build(
      accelerationStructure: accel, descriptor: accelDesc,
      scratchBuffer: scratchBuffer, scratchBufferOffset: 32)
    
    if AccelerationStructureBuilder.doingCompaction {
      accel = self.compact(
        encoder: encoder, accel: accel, descriptor: accelDesc)
    }
    
    // End encoding, and commit the command buffer so the GPU can start building
    // the acceleration structure.
    encoder.endEncoding()
    
    // Return the acceleration structure.
    return accel
  }
  
  mutating func compact(
    encoder: MTLAccelerationStructureCommandEncoder,
    accel: MTLAccelerationStructure,
    descriptor: MTLAccelerationStructureDescriptor
  ) -> MTLAccelerationStructure {
    let desiredSize = accel.size
    var compactedAccel = fetch(
      from: accels, size: desiredSize, index: accelIndex)
    if compactedAccel == nil {
      compactedAccel = create(
        currentSize: &maxAccelSize, desiredSize: desiredSize, {
          $0.makeAccelerationStructure(size: $1)
        })
      compactedAccel!.label = "Molecule (Compacted)"
    }
    guard let compactedAccel else { fatalError("This should never happen.") }
    
    // Encode the command to copy and compact the acceleration structure into
    // the smaller acceleration structure.
    encoder.copyAndCompact(
      sourceAccelerationStructure: accel,
      destinationAccelerationStructure: compactedAccel)
    
    // Re-assign the current acceleration structure to the compacted one.
    append(compactedAccel, to: &accels, index: &accelIndex)
    return compactedAccel
  }
}