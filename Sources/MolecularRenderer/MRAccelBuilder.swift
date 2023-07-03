//
//  MRAccelBuilder.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/17/23.
//

import Metal
import simd

// Partially sourced from:
// https://developer.apple.com/documentation/metal/metal_sample_code_library/control_the_ray_tracing_process_using_intersection_queries

// TODO: Support multiple acceleration structure formats:
// - BVH
// - Dense Grid
// - Sparse Grid
public class MRAccelBuilder {
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  
  // Cache the atoms and don't rebuild if the current frame matches the previous
  // one. This is a very dynamic way to optimize the renderer - it automatically
  // detects frames without motion, and you don't have to explicitly mark frames
  // as static.
  var previousAtoms: [MRAtom] = []
  var previousStyles: [MRAtomStyle] = []
  var currentAtoms: [MRAtom] = []
  var currentStyles: [MRAtomStyle] = []
  
  // Data for compacting the frame after it's been constant for long enough. Do
  // not hold a reference to the accel descriptor for too long, as it retains
  // references to atoms buffers you might want to release.
  var numDuplicateFrames: Int = 0
  var didCompactDuplicateFrame: Bool = false
  var accelDesc: MTLPrimitiveAccelerationStructureDescriptor!
  
  // Triple buffer because the CPU writes to these.
  var atomBuffers: [MTLBuffer?] = Array(repeating: nil, count: 3)
  var boundingBoxBuffers: [MTLBuffer?] = Array(repeating: nil, count: 3)
  
  // Double buffer the accels to remove dependencies between frames.
  // If compaction is enabled, some dependencies will not be removed.
  var scratchBuffers: [MTLBuffer?] = Array(repeating: nil, count: 2)
  var accels: [MTLAccelerationStructure?] = Array(repeating: nil, count: 2)
  
  // Data for uniform grids.
  var denseGridAtoms: MTLBuffer?
  var denseGridData: MTLBuffer?
  var denseGridCounters: MTLBuffer?
  var denseGridReferences: MTLBuffer?
  var globalCounterBuffer: MTLBuffer
  
  // Pipeline state objects.
  var memsetPipeline: MTLComputePipelineState
  var densePass1Pipeline: MTLComputePipelineState
  var densePass2Pipeline: MTLComputePipelineState
  var densePass3Pipeline: MTLComputePipelineState
  
  // Keep track of memory sizes for exponential expansion.
  var maxAtomBufferSize: Int = 1 << 10
  var maxBoundingBoxBufferSize: Int = 1 << 10
  var maxScratchBufferSize: Int = 1 << 10
  var maxAccelSize: Int = 1 << 10
  var maxAtoms: Int = 1 << 1
  var maxGridSlots: Int = 1 << 1
  var maxGridCells: Int = 1 << 1
  var maxGridReferences: Int = 1 << 1
  
  // Indices into ring buffers of memory objects.
  var atomBufferIndex: Int = 0 // modulo 3
  var boundingBoxBufferIndex: Int = 0 // modulo 3
  var scratchBufferIndex: Int = 0 // modulo 2
  var accelIndex: Int = 0 // modulo 2
  
  public init(
    device: MTLDevice,
    commandQueue: MTLCommandQueue,
    library: MTLLibrary
  ) {
    self.device = device
    self.commandQueue = commandQueue
    
    let memsetFunction = library.makeFunction(name: "memset_pattern4")!
    self.memsetPipeline = try! device
      .makeComputePipelineState(function: memsetFunction)
    
    let densePass1Function = library.makeFunction(name: "dense_grid_pass1")!
    self.densePass1Pipeline = try! device
      .makeComputePipelineState(function: densePass1Function)
    
    let densePass2Function = library.makeFunction(name: "dense_grid_pass2")!
    self.densePass2Pipeline = try! device
      .makeComputePipelineState(function: densePass2Function)
    
    let densePass3Function = library.makeFunction(name: "dense_grid_pass3")!
    self.densePass3Pipeline = try! device
      .makeComputePipelineState(function: densePass3Function)
    
    self.globalCounterBuffer = device.makeBuffer(length: 4)!
  }
}

extension MRAccelBuilder {
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

extension MRAccelBuilder {
  // Only call this once per frame.
  internal func build(
    commandBuffer: MTLCommandBuffer
  ) -> MTLAccelerationStructure {
    defer {
      self.previousAtoms = currentAtoms
      self.previousStyles = currentStyles
    }
    
    // Do not generate a new accel when you built a usable one last frame.
    if previousAtoms == currentAtoms,
       previousStyles == currentStyles,
       let accel = self.accels[accelIndex] {
      self.numDuplicateFrames += 1
      if numDuplicateFrames >= 3 && !didCompactDuplicateFrame {
        let encoder = commandBuffer.makeAccelerationStructureCommandEncoder()!
        let output = self.compact(
          encoder: encoder, accel: accel, descriptor: accelDesc)
        encoder.endEncoding()
        
        self.didCompactDuplicateFrame = true
        self.accelDesc = nil
        return output
      } else {
        return accel
      }
    }
    self.numDuplicateFrames = 0
    self.didCompactDuplicateFrame = false
    self.accelDesc = nil
    
    // Generate or fetch a buffer.
    let atomSize = MemoryLayout<MRAtom>.stride
    let atomBufferSize = currentAtoms.count * atomSize
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
        .assumingMemoryBound(to: MRAtom.self)
      for (index, atom) in currentAtoms.enumerated() {
        atomsPointer[index] = atom
      }
    }
    
    // Generate or fetch a buffer.
    let boundingBoxSize = MemoryLayout<MRBoundingBox>.stride
    let boundingBoxBufferSize = currentAtoms.count * boundingBoxSize
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
        .assumingMemoryBound(to: MRBoundingBox.self)
      for (index, atom) in currentAtoms.enumerated() {
        let boundingBox = atom.getBoundingBox(styles: currentStyles)
        boundingBoxesPointer[index] = boundingBox
      }
    }
    
    let geometryDesc = MTLAccelerationStructureBoundingBoxGeometryDescriptor()
    geometryDesc.primitiveDataBuffer = atomBuffer
    geometryDesc.primitiveDataStride = atomSize
    geometryDesc.primitiveDataBufferOffset = 0
    geometryDesc.primitiveDataElementSize = atomSize
    geometryDesc.boundingBoxCount = currentAtoms.count
    geometryDesc.boundingBoxStride = boundingBoxSize
    geometryDesc.boundingBoxBufferOffset = 0
    geometryDesc.boundingBoxBuffer = boundingBoxBuffer
    geometryDesc.allowDuplicateIntersectionFunctionInvocation = false
    
    self.accelDesc = MTLPrimitiveAccelerationStructureDescriptor()
    self.accelDesc.geometryDescriptors = [geometryDesc]
    
    // Query for the sizes needed to store and build the acceleration structure.
    let accelSizes = device.accelerationStructureSizes(descriptor: accelDesc)
    
    // Allocate scratch space Metal uses to build the acceleration structure.
    let scratchBuffer = cycle(
      from: &scratchBuffers,
      index: &scratchBufferIndex,
      currentSize: &maxScratchBufferSize,
      desiredSize: 1024 + accelSizes.buildScratchBufferSize,
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
      scratchBuffer: scratchBuffer, scratchBufferOffset: 1024)
    
    // End encoding, and commit the command buffer so the GPU can start building
    // the acceleration structure.
    encoder.endEncoding()
    
    // Return the acceleration structure.
    return accel
  }
  
  // Compaction saves a lot of memory, but doesn't really change whether it is
  // aligned along cache lines. If anything, it only increases the memory
  // because we now have two scratch buffers.
  private func compact(
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

extension MRAccelBuilder {
  // Utility for exponentially expanding memory allocations.
  private func allocate(
    _ buffer: inout MTLBuffer?,
    currentMaxElements: inout Int,
    desiredElements: Int,
    bytesPerElement: Int
  ) -> MTLBuffer {
    if let buffer, currentMaxElements >= desiredElements {
      return buffer
    }
    while currentMaxElements < desiredElements {
      currentMaxElements = currentMaxElements << 1
    }
    
    let bufferSize = currentMaxElements * bytesPerElement
    let newBuffer = device.makeBuffer(length: bufferSize)!
    buffer = newBuffer
    return newBuffer
  }
  
  internal func buildDenseGrid(encoder: MTLComputeCommandEncoder) {
    // Find the grid size.
    var elementInstances: [Int] = .init(
      repeating: 0, count: currentStyles.count)
    var minCoordinates: SIMD3<Float> = .zero
    var maxCoordinates: SIMD3<Float> = .zero
    for atom in currentAtoms {
      elementInstances[Int(atom.element)] += 1
      
      let radius = atom.getRadius(styles: currentStyles)
      minCoordinates = min(atom.origin - Float(radius), minCoordinates)
      maxCoordinates = min(atom.origin + Float(radius), maxCoordinates)
    }
    let maxMagnitude = max(abs(minCoordinates), abs(maxCoordinates)).max()
    
    let cellWidth: Float = 0.5
    let gridWidth = Int(2 * ceil(maxMagnitude / 0.5))
    let totalCells = gridWidth * gridWidth * gridWidth
    
    // Find the number of references.
    var numReferences = 0
    for (index, numAtoms) in elementInstances.enumerated() {
      // Doesn't support checkerboard-patterned atoms yet.
      let radius = Float(currentStyles[index].radius)
      
      let epsilon: Float = 0.001
      var diameterCellSpan = (2 * radius + epsilon) / cellWidth
      diameterCellSpan = ceil(diameterCellSpan)
      let maxCells = diameterCellSpan * diameterCellSpan * diameterCellSpan
      numReferences += numAtoms * Int(maxCells)
    }
    
    // Allocate new memory.
    let numAtoms = currentAtoms.count
    let atomsBuffer = allocate(
      &denseGridAtoms,
      currentMaxElements: &maxAtoms,
      desiredElements: numAtoms,
      bytesPerElement: 16)
    
    let paddedCells = (totalCells + 127) / 128 * 128
    let numSlots = paddedCells + 1 // include global counter
    let dataBuffer = allocate(
      &denseGridData,
      currentMaxElements: &maxGridSlots,
      desiredElements: numSlots,
      bytesPerElement: 4)
    let countersBuffer = allocate(
      &denseGridCounters,
      currentMaxElements: &maxGridCells,
      desiredElements: totalCells,
      bytesPerElement: 4)
    
    let referencesBuffer = allocate(
      &denseGridReferences,
      currentMaxElements: &maxGridReferences,
      desiredElements: numReferences,
      bytesPerElement: 2)
    
    encoder.setComputePipelineState(memsetPipeline)
    encoder.setBuffer(dataBuffer, offset: 0, index: 0)
    var pattern4: UInt32 = 0
    encoder.setBytes(&pattern4, length: 4, index: 1)
    encoder.dispatchThreads(
      MTLSizeMake(paddedCells, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
    
    // For some reason, Metal Frame Capture fails when we merge the atomic and
    // the grid into the same buffer.
    encoder.setBuffer(globalCounterBuffer, offset: 0, index: 0)
    encoder.dispatchThreads(
      MTLSizeMake(1, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(32, 1, 1))
    
    var constants: UInt16 = UInt16(gridWidth)
    encoder.setBytes(&constants, length: 2, index: 0)
    currentStyles.withUnsafeBufferPointer {
      let length = $0.count * MemoryLayout<MRAtomStyle>.stride
      encoder.setBytes($0.baseAddress!, length: length, index: 1)
    }
    encoder.setBuffer(atomsBuffer, offset: 0, index: 2)
    encoder.setBuffer(dataBuffer, offset: 0, index: 3)
    encoder.setBuffer(countersBuffer, offset: 0, index: 4)
//    encoder.setBuffer(dataBuffer, offset: paddedCells * 4, index: 5)
    encoder.setBuffer(globalCounterBuffer, offset: 0, index: 5)
    encoder.setBuffer(referencesBuffer, offset: 0, index: 6)
    
    encoder.setComputePipelineState(densePass1Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(numAtoms, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(64, 1, 1))
    
    encoder.setComputePipelineState(densePass2Pipeline)
    encoder.dispatchThreadgroups(
      MTLSizeMake(paddedCells / 128, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    
    encoder.setComputePipelineState(densePass3Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(numAtoms, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(64, 1, 1))
  }
}
