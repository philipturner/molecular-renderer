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
    
    // Good range of denominators:
    // [10, 32] exclusive
    //
    // Is the atom radius a good indicator of an optimal cell size?
    // -  8 -> 0.250
    // - 10 -> 0.200
    // - 12 -> 0.167
    // - 14 -> 0.143
    // - 16 -> 0.125
    // - 18 -> 0.111
    // - 22 -> 0.091
    // - 26 -> 0.077
    //
    // Start at 4/10.
    // min(4/8, rint(radius)), loop through this and the next 4 numbers afterward
    // - only use increments of numerator 2 @ denominator 4
    // - use whichever sample in the (very small) history has the minimum
    //   - history has 2 planes (2 samples/cell)
    // - every 1/3 frame: measurement
    // - every 2/3 frames: alternate between the two best cell sizes
    //   - if a cell size has the maximum in the most recent plane of the
    //     history, it cannot be a "best"
    //
    // - log the extended history, then another line, showing which were chosen
    // - also show the results (render time resulting from the choices)
    // - able to turn off the autotuning (and just use 4/9) to benchmark in MFC.
    //
    // Independently track speed of the geometry and render stages. Find a
    // balance between the fastest size for rendering (up close) and the fastest
    // size for geometry building (far away). Then use mixed block sizes once
    // the grid is sparse.
    //
    // Use atomics to generate a grid at 1/2 the spatial resolution as the ideal
    // rendering size (using threadgroup memory atomics). Then, use something
    // compute-intensive to upscale to the full resolution.
    //
    // 0.262 -> 12...15
    // 0.235 -> 11...15
    // 0.162 -> 14...18, 24
    // 0.137 -> 16...20+
    // 0.131 -> 14...22
//    let denominators: [Float] = [8, 10, 12, 14, 16, 18, 20, 22]
//    let denominators: [Float] = [8, 9, 10, 11, 12, 13, 14, 15, 16]
//    let denominators: [Float] = [12, 13, 14, 15, 16, 17, 18]
//    let denominators: [Float] = [10, 12, 14, 16, 18, 20, 22, 24]
//    let denominators: [Float] = [14, 16, 18, 20, 22]
//    let denominators: [Float] = [8, 9, 10, 11, 12, 13]
    let denominators: [Float] = [9]
    for var denominator in denominators {
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
        pipeline: rayTracingPipeline)
      pipelines.append(pipeline)
    }
    self.pipelines = pipelines
    
    self.timesHistoryLength = 2
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
    print(summary())
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
