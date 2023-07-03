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
    
    let constants = MTLFunctionConstantValues()
    var pattern4: UInt32 = 0
    constants.setConstantValue(&pattern4, type: .uint, index: 0)
    
    let memsetFunction = try! library.makeFunction(
      name: "memset_pattern4", constantValues: constants)
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

@inline(never) @_optimize(speed)
fileprivate func denseGridStatistics(
  atoms: [MRAtom],
  styles: [MRAtomStyle]
) -> (boundingBox: MRBoundingBox, references: Int) {
  precondition(atoms.count > 0, "Not enough atoms.")
  precondition(styles.count > 0, "Not enough styles.")
  precondition(styles.count < 255, "Too many styles.")
  
  let elementInstances = malloc(256 * 4)!
    .assumingMemoryBound(to: UInt32.self)
  var pattern4: UInt32 = 0
  memset_pattern4(elementInstances, &pattern4, 256 * 4)
  
  @_alignment(16)
  struct MRAtom4 {
    var atom1: MRAtom
    var atom2: MRAtom
    var atom3: MRAtom
    var atom4: MRAtom
  }
  
  let paddedNumAtoms = (atoms.count + 3) / 4 * 4
  let atomsPadded_raw = malloc(paddedNumAtoms * 16)!
  let atomsPadded_1 = atomsPadded_raw.assumingMemoryBound(to: MRAtom.self)
  let atomsPadded_4 = atomsPadded_raw.assumingMemoryBound(to: MRAtom4.self)
  
  memcpy(atomsPadded_raw, atoms, atoms.count * 16)
  var paddingAtom = atoms[0]
  paddingAtom.element = 255
  for i in atoms.count..<paddedNumAtoms {
    atomsPadded_1[i] = paddingAtom
  }
  
  var minCoordinates: SIMD4<Float> = .zero
  var maxCoordinates: SIMD4<Float> = .zero
  for chunkIndex in 0..<paddedNumAtoms / 4 {
    let chunk = atomsPadded_4[chunkIndex]
    elementInstances[Int(chunk.atom1.element)] &+= 1
    elementInstances[Int(chunk.atom2.element)] &+= 1
    elementInstances[Int(chunk.atom3.element)] &+= 1
    elementInstances[Int(chunk.atom4.element)] &+= 1
    
    let coords1 = unsafeBitCast(chunk.atom1, to: SIMD4<Float>.self)
    let coords2 = unsafeBitCast(chunk.atom2, to: SIMD4<Float>.self)
    let coords3 = unsafeBitCast(chunk.atom3, to: SIMD4<Float>.self)
    let coords4 = unsafeBitCast(chunk.atom4, to: SIMD4<Float>.self)
    let min12 = simd_min(coords1, coords2)
    let min34 = simd_min(coords3, coords4)
    let min1234 = simd_min(min12, min34)
    minCoordinates = simd_min(min1234, minCoordinates)
    
    let max12 = simd_max(coords1, coords2)
    let max34 = simd_max(coords3, coords4)
    let max1234 = simd_max(max12, max34)
    maxCoordinates = simd_max(max1234, maxCoordinates)
  }
  
  let cellWidth: Float = 0.5
  let epsilon: Float = 1e-4
  var references: Int = 0
  var maxRadius: Float = 0
  for i in 0..<styles.count {
    let radius = Float(styles[i].radius)
    let cellSpan = ceil((2 * radius + epsilon) / cellWidth)
    let cellCube = cellSpan * cellSpan * cellSpan
    
    let instances = elementInstances[i]
    references &+= Int(instances &* UInt32(cellCube))
    
    let presentMask: Float = (instances > 0) ? 1 : 0
    maxRadius = max(radius * presentMask, maxRadius)
  }
  maxRadius += epsilon
  minCoordinates -= maxRadius
  maxCoordinates += maxRadius
  
  free(elementInstances)
  free(atomsPadded_raw)
  
  let boundingBox = MRBoundingBox(
    min: MTLPackedFloat3Make(
      minCoordinates.x, minCoordinates.y, minCoordinates.z),
    max: MTLPackedFloat3Make(
      maxCoordinates.x, maxCoordinates.y, maxCoordinates.z))
  return (boundingBox, references)
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
    let statistics = denseGridStatistics(
      atoms: currentAtoms, styles: currentStyles)
    
    let minCoordinates = SIMD3(statistics.boundingBox.min.x,
                               statistics.boundingBox.min.y,
                               statistics.boundingBox.min.z)
    let maxCoordinates = SIMD3(statistics.boundingBox.max.x,
                               statistics.boundingBox.max.y,
                               statistics.boundingBox.max.z)
    let maxMagnitude = max(abs(minCoordinates), abs(maxCoordinates)).max()

    let cellWidth: Float = 0.5
    let gridWidth = Int(2 * ceil(maxMagnitude / cellWidth))
    let totalCells = gridWidth * gridWidth * gridWidth
    let numReferences = statistics.references
    
    // Allocate new memory.
    let numAtoms = currentAtoms.count
    let atomsBuffer = allocate(
      &denseGridAtoms,
      currentMaxElements: &maxAtoms,
      desiredElements: numAtoms,
      bytesPerElement: 16)
    
    let paddedCells = (totalCells + 127) / 128 * 128
    let numSlots = paddedCells
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
    encoder.dispatchThreads(
      MTLSizeMake(paddedCells, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
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
    encoder.setBuffer(globalCounterBuffer, offset: 0, index: 5)
    encoder.setBuffer(referencesBuffer, offset: 0, index: 6)
    
    encoder.setComputePipelineState(densePass1Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(numAtoms, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    
    encoder.setComputePipelineState(densePass2Pipeline)
    encoder.dispatchThreadgroups(
      MTLSizeMake(paddedCells / 128, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    
    encoder.setComputePipelineState(densePass3Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(numAtoms, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
}
