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

// TODO: Change this function to "setAtomProvider" and move into MRAtom.swift.

extension MRRenderer {
  public func setGeometry(
    time: MRTimeContext,
    atomProvider: inout MRAtomProvider,
    styleProvider: MRAtomStyleProvider,
    useMotionVectors: Bool
  ) {
    self.time = time
    
    if accelBuilder.sceneSize == .extreme, accelBuilder.builtGrid {
      return
    }
    
    var atoms = atomProvider.atoms(time: time)
    let styles = styleProvider.styles
    let available = styleProvider.available
    
    for i in atoms.indices {
      let element = Int(atoms[i].element)
      if available[element] {
        let radius = styles[element].radius
        atoms[i].radiusSquared = radius * radius
        atoms[i].flags = 0
      } else {
        let radius = styles[0].radius
        atoms[i].element = 0
        atoms[i].radiusSquared = radius * radius
        atoms[i].flags = 0x1 | 0x2
      }
    }
    
    if useMotionVectors {
      guard accelBuilder.atoms.count == atoms.count else {
        fatalError(
          "Used motion vectors when last frame had different atom count.")
      }
      
      accelBuilder.motionVectors = (0..<atoms.count).map { i -> SIMD3<Float> in
        atoms[i].origin - accelBuilder.atoms[i].origin
      }
    } else {
      accelBuilder.motionVectors = Array(repeating: .zero, count: atoms.count)
    }
    
    self.accelBuilder.atoms = atoms
    self.accelBuilder.styles = styles
  }
}
