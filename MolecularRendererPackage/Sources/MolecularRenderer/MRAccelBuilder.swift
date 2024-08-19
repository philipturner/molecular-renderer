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

// There should be an option to enable this performance reporting mechanism, in
// the descriptor for 'MRRenderer'.
struct MRFrameReport {
  // The ID of the frame that owns this report.
  var frameID: Int
  
  // CPU time spent preparing geometry.
  var preprocessingTimeCPU: Double
  
  // CPU time spent copying geometry into GPU buffer.
  var copyingTime: Double
  
  // GPU time spent preparing geometry.
  var preprocessingTimeGPU: Double
  
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
  var atomStyles: [MRAtomStyle] = []
  var motionVectors: [SIMD3<Float>] = []
  
  // Triple-buffer because the CPU accesses these.
  var motionVectorBuffers: [MTLBuffer?] = [nil, nil, nil]
  var denseGridAtoms: [MTLBuffer?] = [nil, nil, nil]
  
  // Safeguard access to these using a dispatch queue.
  var reportPerformance: Bool = false
  var frameReportQueue: DispatchQueue = .init(
    label: "com.philipturner.MolecularRenderer.MRAccelBuilder.frameReportQueue")
  var frameReports: [MRFrameReport] = []
  var frameReportCounter: Int = 0
  static let frameReportHistorySize: Int = 10
  
  // Data for uniform grids.
  var worldOrigin: SIMD3<Int16> = .zero
  var worldDimensions: SIMD3<Int16> = .zero
  var ringIndex: Int = 0
  var denseGridData: MTLBuffer?
  var denseGridCounters: MTLBuffer?
  var denseGridReferences: MTLBuffer?
  
  // Pipeline state objects.
  var memsetPipeline: MTLComputePipelineState
  var densePass1Pipeline: MTLComputePipelineState
  var densePass2Pipeline: MTLComputePipelineState
  var densePass3Pipeline: MTLComputePipelineState
  
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
    desiredSize: Int,
    name: String
  ) -> MTLBuffer {
    // Either find a valid buffer or report the size of the existing one.
    var previousSize = 0
    var resource: MTLBuffer?
    if let buffer = buffers[index] {
      if buffer.allocatedSize < desiredSize {
        previousSize = buffer.allocatedSize
      } else {
        resource = buffer
      }
    }
    
    // If necessary, create a new buffer.
    if resource == nil {
      var maximumSize = max(1, previousSize)
      while maximumSize < desiredSize {
        maximumSize = maximumSize << 1
      }
      
      guard let buffer = device.makeBuffer(length: maximumSize) else {
        fatalError(
          "Could not create buffer with size \(maximumSize).")
      }
      resource = buffer
      resource!.label = name
    }
    guard let resource else { fatalError("This should never happen.") }
    
    // Overwrite the existing reference with the returned one.
    buffers[index] = resource
    return resource
  }
  
  func allocate(
    _ buffer: inout MTLBuffer?,
    desiredElements: Int,
    bytesPerElement: Int
  ) -> MTLBuffer {
    if let buffer,
       buffer.length >= desiredElements * bytesPerElement {
      return buffer
    }
    var maxElements = (buffer?.length ?? 0) / bytesPerElement
    while maxElements < desiredElements {
      maxElements = max(1, maxElements << 1)
    }
    
    let bufferSize = maxElements * bytesPerElement
    let newBuffer = device.makeBuffer(length: bufferSize)!
    buffer = newBuffer
    return newBuffer
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
  // Call this after encoding the grid construction.
  func setGridWidth(arguments: inout Arguments) {
    precondition(
      all(worldDimensions .> 0), "Forgot to encode the grid construction.")
    arguments.worldOrigin = worldOrigin
    arguments.worldDimensions = worldDimensions
  }
  
  // For extreme systems, cell this repeatedly and only call 'buildDenseGrid'
  // one time. That ensures only a single instance of the grid is allocated in
  // memory, enabling extremely massive scenes.
  func encodeGridArguments(encoder: MTLComputeCommandEncoder) {
    // Set the data at offset 32, to fit the counters before it.
    encoder.setBuffer(denseGridAtoms[ringIndex]!, offset: 0, index: 3)
    encoder.setBuffer(denseGridData!, offset: 32, index: 4)
    encoder.setBuffer(denseGridReferences!, offset: 0, index: 5)
    encoder.setBuffer(motionVectorBuffers[ringIndex]!, offset: 0, index: 6)
  }
}
