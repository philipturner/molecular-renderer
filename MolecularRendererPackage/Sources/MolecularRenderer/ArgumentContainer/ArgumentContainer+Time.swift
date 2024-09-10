//
//  ArgumentContainer+Time.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

extension ArgumentContainer {
  func doubleBufferIndex() -> Int {
    frameID % 2
  }
  
  func tripleBufferIndex() -> Int {
    frameID % 3
  }
  
  func haltonIndex() -> Int {
    (frameID % 32) + 1
  }
}

// MARK: - API

public struct MRTime {
  // Absolute time. Atom providers should check whether this jumps to zero.
  public var absolute: (frames: Int, seconds: Double)
  
  // Number of frames since the last frame, typically 1. This does not always
  // agree with the absolute time.
  public var relative: (frames: Int, seconds: Double)
  
  // MolecularRenderer measures time in integer quantities, allowing vsync and
  // indexing into arrays of pre-recorded animation frames. The frame rate is
  // the granularity of these measurements.
  public init(absolute: Int, relative: Int, frameRate: Int) {
    func makeTime(frames: Int, frameRate: Int) -> (Int, Double) {
      let frames = frames
      let fractionalPart = frames % frameRate
      
      var seconds = Double(frames / frameRate)
      seconds += Double(fractionalPart) / Double(frameRate)
      return (frames, seconds)
    }
    
    self.absolute = makeTime(frames: absolute, frameRate: frameRate)
    self.relative = makeTime(frames: relative, frameRate: frameRate)
  }
}

extension MRRenderer {
  public func setTime(_ time: MRTime) {
    argumentContainer.currentTime = time
  }
}
