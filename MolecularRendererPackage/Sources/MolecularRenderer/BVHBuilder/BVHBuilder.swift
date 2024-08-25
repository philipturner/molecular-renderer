//
//  BVHBuilder.swift
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

class BVHBuilder {
  // Main rendering resources.
  var device: MTLDevice
  unowned var renderer: MRRenderer
  var motionVectors: [SIMD3<Float>] = []
  
  // Safeguard access to these using a dispatch queue.
  var reportPerformance: Bool = false
  var frameReportQueue: DispatchQueue = .init(
    label: "com.philipturner.MolecularRenderer.BVHBuilder.frameReportQueue")
  var frameReports: [MRFrameReport] = []
  var frameReportCounter: Int = 0
  static let frameReportHistorySize: Int = 10
  
  // Data for uniform grids.
  var worldOrigin: SIMD3<Int16> = .zero
  var worldDimensions: SIMD3<Int16> = .zero
  var denseGridData: MTLBuffer?
  var denseGridCounters: MTLBuffer?
  var denseGridReferences: MTLBuffer?
  
  // Resources for the old BVH building algorithm.
  var denseGridAtoms: [MTLBuffer] = []
  var motionVectorBuffers: [MTLBuffer] = []
  
  // Resources for the new BVH building algorithm.
  var preprocessPipeline: MTLComputePipelineState
  var newAtomsBuffers: [MTLBuffer]
  
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
    self.renderer = renderer
    
    // Initialize the memset shader.
    let constants = MTLFunctionConstantValues()
    var pattern4: UInt32 = 0
    constants.setConstantValue(&pattern4, type: .uint, index: 1000)
    
    let memsetFunction = try! library.makeFunction(
      name: "memset_pattern4", constantValues: constants)
    self.memsetPipeline = try! device
      .makeComputePipelineState(function: memsetFunction)
    
    // Initialize shaders for the old BVH construction algorithm.
    let densePass1Function = library.makeFunction(name: "dense_grid_pass1")!
    let densePass2Function = library.makeFunction(name: "dense_grid_pass2")!
    let densePass3Function = library.makeFunction(name: "dense_grid_pass3")!
    self.densePass1Pipeline = try! device
      .makeComputePipelineState(function: densePass1Function)
    self.densePass2Pipeline = try! device
      .makeComputePipelineState(function: densePass2Function)
    self.densePass3Pipeline = try! device
      .makeComputePipelineState(function: densePass3Function)
    
    // Allocate resources for the old BVH building algorithm.
    func createAtomBuffer(device: MTLDevice) -> MTLBuffer {
      // Limited to 4 million atoms for now.
      let bufferSize: Int = (4 * 1024 * 1024) * 16
      return device.makeBuffer(length: bufferSize)!
    }
    denseGridAtoms = [
      createAtomBuffer(device: device),
      createAtomBuffer(device: device),
      createAtomBuffer(device: device),
    ]
    motionVectorBuffers = [
      createAtomBuffer(device: device),
      createAtomBuffer(device: device),
      createAtomBuffer(device: device),
    ]
    
    // Allocate resources for the new BVH building algorithm.
    preprocessPipeline = Self.createPreprocessFunction(
      device: device, library: library)
    newAtomsBuffers = [
      createAtomBuffer(device: device),
      createAtomBuffer(device: device),
    ]
  }
}

extension BVHBuilder {
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
