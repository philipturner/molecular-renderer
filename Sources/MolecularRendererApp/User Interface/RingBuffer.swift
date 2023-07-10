//
//  RingBuffer.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/9/23.
//

import Foundation
import MolecularRenderer
import simd

// Takes the average of the last N positions, to smooth out sudden jolts caused
// by imperfect sampling. This decreases nausea and perceived stuttering. The
// motion lag is (N - 1)/2 and the noise scales with rsqrt(N). However, the
// reference system only needs 2 samples to smooth out most noise.
struct RingBuffer{
  private var history: [Orientation]
  private var index: Int = 0
  var last: Orientation
  
  init(repeating value: Orientation, count: Int) {
    self.history = .init(repeating: value, count: count)
    self.last = value
  }
  
  mutating func store(_ value: Orientation) {
    defer {
      index = (index + 1) % history.count
    }
    
    self.history[index] = value
    self.last = value
  }
  
  func load() -> Orientation {
    Orientation(averaging: history)
  }
}

// Keeps track of how long you have been sprinting for. Used to determine how to
// dilate the FOV.
struct SprintingHistory {
  typealias Sample = (timer: Double, sprinting: Bool)
  
  private var samples: [Sample] = []
  
  private var timeout: Double = 0.1
  
  // Progress between the standard FOV and the target FOV.
  var progress: Float { _progress! }
  private var _progress: Float?
  
  mutating func update(time: MRTimeContext, sprinting: Bool) {
    var newSamples: [Sample] = []
    for var sample in samples {
      sample.timer -= time.relative.seconds
      if sample.timer > 0 {
        newSamples.append(sample)
      }
    }
    newSamples.append((timeout, sprinting))
    
    self.samples = newSamples
    self.updateRawProgress()
  }
  
  private mutating func updateRawProgress() {
    guard samples.count > 0 else {
      _progress = 0
      return
    }
    var trueSamples: Int = 0
    for sample in samples where sample.sprinting {
      trueSamples += 1
    }
    var t = Float(trueSamples) / Float(samples.count)
    
    // This heuristic might fail if the framerate is too jumpy.
    let amountFilled = 1 - samples.first!.timer / timeout
    let fillCutoff: Double = 0.5
    if amountFilled < fillCutoff {
      t *= Float(amountFilled / fillCutoff)
    }
    
    func smoothstep(edge0: Float, edge1: Float, x: Float) -> Float {
      let t = simd_clamp((x - edge0) / (edge1 - edge0), Float(0), Float(1))
      return t * t * (Float(3) - Float(2) * t)
    }
    _progress = 2 * smoothstep(edge0: 0, edge1: 1, x: t / 2)
  }
}
