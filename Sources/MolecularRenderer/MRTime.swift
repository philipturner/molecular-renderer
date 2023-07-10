//
//  MRTime.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 7/9/23.
//

import Foundation

@usableFromInline
internal var globalFrameRate: Int?

// MolecularRenderer measures time in integer quantities, allowing vsync and
// indexing into arrays of pre-recorded animation frames. The global frame rate
// is the granularity of these measurements.
//
// TODO: In the app, set the frame rate to match the current display. The
// rendering context cannot switch displays while rendering.
@_cdecl("MRSetFrameRate")
public func MRSetFrameRate(_ frameRate: Int) {
  globalFrameRate = frameRate
}

@_cdecl("MRGetFrameRate")
public func MRGetFrameRate() -> Int {
  return globalFrameRate!
}

// MARK: - Data Structures

public struct MRTime {
  public var frames: Int
  public var seconds: Double
  
  @inlinable
  public init(frames: Int) {
    self.frames = frames
    
    let frameRate = globalFrameRate!
    self.seconds = Double(frames / frameRate)
    
    let fractionalPart = frames % frameRate
    self.seconds += Double(fractionalPart) / Double(frameRate)
  }
}

public struct MRTimeContext {
  // Absolute time. Atom providers should check whether this jumps to zero.
  // TODO: Connect resets to MetalFX upscaling, which needs to be notified of
  // sudden scene changes.
  public var absolute: MRTime
  
  // Number of frames since the last frame, typically 1. This does not always
  // agree with the absolute time.
  public var relative: MRTime
  
  @inlinable
  public init(absolute: Int, relative: Int) {
    self.absolute = MRTime(frames: absolute)
    self.relative = MRTime(frames: relative)
  }
}
