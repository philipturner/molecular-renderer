//
//  MRProfiler.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 7/14/23.
//

import Metal

struct PipelineConfig {
  var voxelWidthNumer: Float
  var voxelWidthDenom: Float
  var cellSphereTest: Bool
  var pipeline: MTLComputePipelineState
}

struct ProfilingTracker {
  var geometrySemaphores: [DispatchSemaphore] = [
    DispatchSemaphore(value: 1),
    DispatchSemaphore(value: 1),
    DispatchSemaphore(value: 1),
  ]
  var renderSemaphores: [DispatchSemaphore] = [
    DispatchSemaphore(value: 1),
    DispatchSemaphore(value: 1),
    DispatchSemaphore(value: 1),
  ]
  var queuedIDs: SIMD3<Int> = SIMD3(repeating: -1)
  var queuedGeometryTimes: SIMD3<Double> = SIMD3(repeating: -1)
  var queuedRenderTimes: SIMD3<Double> = SIMD3(repeating: -1)
  var queuedRmsAtomRadii: SIMD3<Float> = SIMD3(repeating: -1)
  var queuedValues: SIMD3<Float> = SIMD3(repeating: -1)
  var queuedCounts: SIMD3<Float> = SIMD3(repeating: -1)
}

class MRProfiler {
  var pipelines: [PipelineConfig]
  var counter: Int
  var tracker: ProfilingTracker
  
  var timesHistoryLength: Int
  var times: [Int: [SIMD2<Double>]]
  var radiiHistoryLength: Int
  var radii: [Float]
  
  init(renderer: MRRenderer, library: MTLLibrary) {
    self.pipelines = []
    self.counter = 0
    self.tracker = .init()
    
    // Initialize resolution and aspect ratio for rendering.
    let constants = MTLFunctionConstantValues()
    
    // Actual texture width.
    var screenWidth: UInt32 = .init(renderer.intermediateSize.x)
    constants.setConstantValue(&screenWidth, type: .uint, index: 0)
    
    // Actual texture height.
    var screenHeight: UInt32 = .init(renderer.intermediateSize.y)
    constants.setConstantValue(&screenHeight, type: .uint, index: 1)
    
    var suppressSpecular: Bool = false
    constants.setConstantValue(&suppressSpecular, type: .bool, index: 2)
    
    var numerator: Float = 4
    constants.setConstantValue(&numerator, type: .float, index: 10)
    
    var pipelines: [PipelineConfig] = []
    let configs: [(Float, Bool)] = [
      (16, true),
    ]
    for config in configs {
      var denominator = config.0
      constants.setConstantValue(&denominator, type: .float, index: 11)
      
      // Initialize the compute pipeline.
      let function = try! library.makeFunction(
        name: "renderMain", constantValues: constants)
      
      let desc = MTLComputePipelineDescriptor()
      desc.computeFunction = function
      desc.maxTotalThreadsPerThreadgroup = 1024
      let rayTracingPipeline = try! renderer.device
        .makeComputePipelineState(
          descriptor: desc, options: [], reflection: nil)
      
      let pipeline = PipelineConfig(
        voxelWidthNumer: numerator,
        voxelWidthDenom: denominator,
        cellSphereTest: config.1,
        pipeline: rayTracingPipeline)
      pipelines.append(pipeline)
    }
    self.pipelines = pipelines
    
    self.timesHistoryLength = 30 / configs.count
    self.times = [:]
    for i in 0..<pipelines.count {
      self.times[i] = []
    }
    self.radiiHistoryLength = 30
    self.radii = []
  }
  
  func currentPipeline() -> PipelineConfig {
    return pipelines[currentID()]
  }
  
  func currentID() -> Int {
    return counter % pipelines.count
  }
  
  func update(ringIndex: Int) {
    self.counter += 1
    let id = tracker.queuedIDs[ringIndex]
    let count = tracker.queuedCounts[ringIndex]
    if id != -1 && count > 1 {
      var array = times[id]!
      array.append(SIMD2(
        tracker.queuedGeometryTimes[ringIndex],
        tracker.queuedRenderTimes[ringIndex]))
      while array.count > timesHistoryLength {
        array.removeFirst()
      }
      times[id] = array
      
      let radius = tracker.queuedRmsAtomRadii[ringIndex]
      radii.append(radius)
      while radii.count > radiiHistoryLength {
        radii.removeFirst()
      }
    }
  }
  
  func summary() -> String {
    var minTimes = [SIMD2<Int>](repeating: [-1, -1], count: pipelines.count)
    for i in 0..<pipelines.count {
      if let array = times[i] {
        let minSeconds = array.reduce(SIMD2<Double>(1, 1)) {
          return SIMD2(
            min($0[0], $1[0]),
            min($0[1], $1[1]))
        }
        let minMicroseconds = SIMD2<Int>(minSeconds * 1e6)
        minTimes[i] = minMicroseconds
      }
    }
    if minTimes.contains(SIMD2(-1, -1)) || radii.count == 0 {
      return ""
    } else {
      var reprs = minTimes.map {
        String("\($0[0]) / \($0[1]) µs")
      }
      let averageRadius = radii.reduce(0, +) / Float(radii.count)
      reprs.append(String(format: "%.3f", averageRadius))
      return reprs.joined(separator: ", ")
    }
  }
}
