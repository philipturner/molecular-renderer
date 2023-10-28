//
//  MRAccelBuilder.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/17/23.
//

import Accelerate
import Metal
import simd
import QuartzCore

struct MRFrameReport {
  // The ID of the frame that owns this report.
  var frameID: Int
  
  // CPU time spent preparing geometry.
  var preprocessingTime: Double
  
  // GPU time spent building the uniform grid.
  var geometryTime: Double
  
  // GPU time spent rendering.
  var renderTime: Double
}

class MRAccelBuilder {
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  unowned var renderer: MRRenderer
  var atoms: [MRAtom] = []
  var styles: [MRAtomStyle] = []
  var motionVectors: [SIMD3<Float>] = []
  
  // Triple-buffer because the CPU accesses these.
  var motionVectorBuffers: [MTLBuffer?] = [nil, nil, nil]
  var denseGridAtoms: [MTLBuffer?] = [nil, nil, nil]
  
  // Safeguard access to these using a dispatch queue.
  var frameReportQueue: DispatchQueue = .init(
    label: "com.philipturner.MolecularRenderer.MRAccelBuilder.frameReportQueue")
  var frameReports: [MRFrameReport] = []
  var frameReportCounter: Int = 0
  static let frameReportHistorySize: Int = 10
  
  // Data for uniform grids.
  var ringIndex: Int = 0
  var denseGridData: MTLBuffer?
  var denseGridCounters: MTLBuffer?
  var denseGridReferences: MTLBuffer?
  
  // Pipeline state objects.
  var memsetPipeline: MTLComputePipelineState
  var densePass1Pipeline: MTLComputePipelineState
  var densePass2Pipeline: MTLComputePipelineState
  var densePass3Pipeline: MTLComputePipelineState
  
  // Keep track of memory sizes for exponential expansion.
  var maxAtomBufferSize: Int = 1 << 1
  var maxAtoms: Int = 1 << 1
  var maxGridSlots: Int = 1 << 1
  var maxGridCells: Int = 1 << 1
  var maxGridReferences: Int = 1 << 1
  var gridWidth: Int = 0
  
  public init(
    renderer: MRRenderer,
    library: MTLLibrary
  ) {
    self.device = renderer.device
    self.commandQueue = renderer.commandQueue
    self.renderer = renderer
    
    let constants = MTLFunctionConstantValues()
    var pattern4: UInt32 = 0
    constants.setConstantValue(&pattern4, type: .uint, index: 1000)
    
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
  }
}

extension MRAccelBuilder {
  // The entire process of fetching, resizing, and nil-coalescing.
  func cycle(
    from buffers: inout [MTLBuffer?],
    index: Int,
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
    append(resource, to: &buffers, index: index)
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
    index: Int
  ) {
    buffers[index] = object
  }
}

// Only call these methods once per frame.
extension MRAccelBuilder {
  func updateResources() {
    ringIndex = (ringIndex + 1) % 3
    
    // Generate or fetch a buffer.
    let atomSize = MemoryLayout<MRAtom>.stride
    let atomBufferSize = atoms.count * atomSize
    precondition(atomSize == 16, "Unexpected atom size.")
    
    let motionVectorSize = MemoryLayout<SIMD3<Float>>.stride
    let motionVectorBufferSize = motionVectors.count * motionVectorSize
    precondition(motionVectorSize == 16, "Unexpected motion vector size.")
    let motionVectorBuffer = cycle(
      from: &motionVectorBuffers,
      index: ringIndex,
      currentSize: &maxAtomBufferSize,
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
  
  func buildDenseGrid(
    encoder: MTLComputeCommandEncoder
  ) {
    // TODO: Automatically switch between the two modes, based on which one is
    // faster or which one has enough capacity. With the optimization below,
    // capacity may become the deciding factor.
    //
    // TODO: Sort contiguous blocks of atoms. Those which are spatially local,
    // get an optimized shader that performs a memory operation or an atomic on
    // the entire group. Summarize statistics about the group and send them to
    // the GPU, to reduce the number of memory accesses during the shader. Make
    // it legal to allocate slightly more references than needed, to accomodate
    // all the atoms in the group that could theoretically intersect.
    let voxel_width_numer: Float = 4
    let voxel_width_denom: Float = 8
    let statisticsStart = CACurrentMediaTime()
    let statistics = denseGridStatistics(
      atoms: atoms,
      styles: styles,
      voxel_width_numer: voxel_width_numer,
      voxel_width_denom: [16, voxel_width_denom])
    let statisticsEnd = CACurrentMediaTime()
    let statisticsDuration = statisticsEnd - statisticsStart
    
    // The first rendered frame will have an ID of 1.
    frameReportCounter += 1
    let performance = frameReportQueue.sync { () -> SIMD3<Double> in
      // Remove frames too far back in the history.
      let minimumID = frameReportCounter - Self.frameReportHistorySize
      while frameReports.count > 0, frameReports.first!.frameID < minimumID {
        frameReports.removeFirst()
      }
      
      var dataSize: Int = 0
      var output: SIMD3<Double> = .zero
      for report in frameReports {
        if report.geometryTime >= 0, report.renderTime >= 0 {
          dataSize += 1
          output[0] += report.preprocessingTime
          output[1] += report.geometryTime
          output[2] += report.renderTime
        }
      }
      if dataSize > 0 {
        output /= Double(dataSize)
      }
      
      let report = MRFrameReport(
        frameID: frameReportCounter,
        preprocessingTime: statisticsDuration,
        geometryTime: 1,
        renderTime: 1)
      frameReports.append(report)
      return output
    }
    if any(performance .> 0) {
      print(
        Int(performance[0] * 1e6),
        Int(performance[1] * 1e6),
        Int(performance[2] * 1e6))
    }
    
    let minCoordinates = SIMD3(statistics.boundingBox.min.x,
                               statistics.boundingBox.min.y,
                               statistics.boundingBox.min.z)
    let maxCoordinates = SIMD3(statistics.boundingBox.max.x,
                               statistics.boundingBox.max.y,
                               statistics.boundingBox.max.z)
    let maxMagnitude = max(abs(minCoordinates), abs(maxCoordinates)).max()
    
    // TODO: Change the grid to be rectangular.
    self.gridWidth = max(Int(2 * ceil(
      maxMagnitude * voxel_width_denom / voxel_width_numer)), gridWidth)
    let totalCells = gridWidth * gridWidth * gridWidth
    guard statistics.references[1] < 16 * 1024 * 1024 else {
      fatalError("Too many references for a dense grid.")
    }
    print(
      "References:",
      "\(statistics.references[0] / 1000)k,",
      "\(statistics.references[1] / 1000)k")
    
    // Allocate new memory.
    let atomsBuffer = allocate(
      &denseGridAtoms[ringIndex],
      currentMaxElements: &maxAtoms,
      desiredElements: atoms.count,
      bytesPerElement: 16)
    memcpy(denseGridAtoms[ringIndex]!.contents(), atoms, atoms.count * 16)
    
    // Add 8 to the number of slots, so the counters can be located at the start
    // of the buffer.
    let numSlots = (totalCells + 127) / 128 * 128
    let dataBuffer = allocate(
      &denseGridData,
      currentMaxElements: &maxGridSlots,
      desiredElements: 8 + numSlots,
      bytesPerElement: 4)
    let countersBuffer = allocate(
      &denseGridCounters,
      currentMaxElements: &maxGridCells,
      desiredElements: totalCells,
      bytesPerElement: 4)
    
    let referencesBuffer = allocate(
      &denseGridReferences,
      currentMaxElements: &maxGridReferences,
      desiredElements: statistics.references[1],
      bytesPerElement: 4) // 2
    
    encoder.setComputePipelineState(memsetPipeline)
    encoder.setBuffer(dataBuffer, offset: 0, index: 0)
    encoder.dispatchThreads(
      MTLSizeMake(8 + numSlots, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
    
    struct UniformGridArguments {
      var gridWidth: UInt16
      var cellSphereTest: UInt16
      var worldToVoxelTransform: Float
    }
    
    var arguments: UniformGridArguments = .init(
      gridWidth: UInt16(gridWidth),
      cellSphereTest: 1,
      worldToVoxelTransform: voxel_width_denom / voxel_width_numer)
    let argumentsStride = MemoryLayout<UniformGridArguments>.stride
    encoder.setBytes(&arguments, length: argumentsStride, index: 0)
    
    styles.withUnsafeBufferPointer {
      let length = $0.count * MemoryLayout<MRAtomStyle>.stride
      encoder.setBytes($0.baseAddress!, length: length, index: 1)
    }
    // Set the data at offset 32, to fit the counters before it.
    encoder.setBuffer(atomsBuffer, offset: 0, index: 2)
    encoder.setBuffer(dataBuffer, offset: 32, index: 3)
    encoder.setBuffer(countersBuffer, offset: 0, index: 4)
    encoder.setBuffer(dataBuffer, offset: ringIndex * 4, index: 5)
    encoder.setBuffer(referencesBuffer, offset: 0, index: 6)
    encoder.setBuffer(dataBuffer, offset: ringIndex * 4 + 16, index: 7)
    
    encoder.setComputePipelineState(densePass1Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    
    encoder.setComputePipelineState(densePass2Pipeline)
    encoder.dispatchThreadgroups(
      MTLSizeMake(numSlots / 128, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
    
    encoder.setComputePipelineState(densePass3Pipeline)
    encoder.dispatchThreads(
      MTLSizeMake(atoms.count, 1, 1),
      threadsPerThreadgroup: MTLSizeMake(128, 1, 1))
  }
  
  // Call this after encoding the grid construction.
  func setGridWidth(arguments: inout Arguments) {
    precondition(gridWidth > 0, "Forgot to encode the grid construction.")
    arguments.denseWidth = UInt16(self.gridWidth)
  }
  
  func encodeGridArguments(encoder: MTLComputeCommandEncoder) {
    // Set the data at offset 32, to fit the counters before it.
    encoder.setBuffer(denseGridAtoms[ringIndex]!, offset: 0, index: 3)
    encoder.setBuffer(denseGridData!, offset: 32, index: 4)
    encoder.setBuffer(denseGridReferences!, offset: 0, index: 5)
    encoder.setBuffer(motionVectorBuffers[ringIndex]!, offset: 0, index: 6)
  }
}

