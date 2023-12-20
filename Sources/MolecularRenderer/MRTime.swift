//
//  MRTime.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 7/9/23.
//

import Foundation

// MARK: - MRTime

public struct MRTime {
  public var frames: Int
  public var seconds: Double
  
  @inlinable
  public init(frames: Int, frameRate: Int) {
    self.frames = frames
    self.seconds = Double(frames / frameRate)
    
    let fractionalPart = frames % frameRate
    self.seconds += Double(fractionalPart) / Double(frameRate)
  }
}

public struct MRTimeContext {
  // Absolute time. Atom providers should check whether this jumps to zero.
  public var absolute: MRTime
  
  // Number of frames since the last frame, typically 1. This does not always
  // agree with the absolute time.
  public var relative: MRTime
  
  // MolecularRenderer measures time in integer quantities, allowing vsync and
  // indexing into arrays of pre-recorded animation frames. The frame rate is the
  // granularity of these measurements.
  @inlinable
  public init(absolute: Int, relative: Int, frameRate: Int) {
    self.absolute = MRTime(frames: absolute, frameRate: frameRate)
    self.relative = MRTime(frames: relative, frameRate: frameRate)
  }
}

// Track when to reset the MetalFX upscaler.
struct ResetTracker {
  var currentFrameID: Int = -1
  var resetUpscaler: Bool = false
  
  mutating func update(time: MRTimeContext) {
    let nextFrameID = time.absolute.frames
    if nextFrameID == 0 && nextFrameID != currentFrameID {
      resetUpscaler = true
    } else {
      resetUpscaler = false
    }
    currentFrameID = nextFrameID
  }
}

// MARK: - MRRenderer Methods

extension MRRenderer {
  public func setTime(_ time: MRTimeContext) {
    self.time = time
  }
}
