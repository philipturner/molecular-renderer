//
//  Upscaler.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/21/23.
//

import Metal

// Partially sourced from:
// https://developer.apple.com/documentation/metalfx/applying_temporal_antialiasing_and_upscaling_using_metalfx

struct Upscaler {
  var jitterFrameID: Int = 0
  var jitterOffsets: SIMD2<Float> = .zero
  static let doingUpscaling = true
  
  // Double-buffer the textures to remove resource dependency.
  // TODO: The textures
  // TODO: The texture index is simply [jitterFrameID % 2]
  
  init(renderer: Renderer) {
    
  }
}

extension Upscaler {
  mutating func updateResources() {
    self.jitterFrameID += 1
    self.jitterOffsets = makeJitterOffsets()
    
    guard Upscaler.doingUpscaling else {
      // Not using intermediate textures.
      return
    }
    
    // Swap out the textures for rendering...
  }
  
  private func makeJitterOffsets() -> SIMD2<Float> {
    if Upscaler.doingUpscaling == false {
      return SIMD2.zero
    }
    
    func halton(index: UInt32, base: UInt32) -> Float {
      var result: Float = 0.0
      var fractional: Float = 1.0
      var currentIndex: UInt32 = index
      while currentIndex > 0 {
        fractional /= Float(base)
        result += fractional * Float(currentIndex % base)
        currentIndex /= base
      }
      return result
    }
    
    // The sample uses a Halton sequence rather than purely random numbers to
    // generate the sample positions to ensure good pixel coverage. This has the
    // result of sampling a different point within each pixel every frame.
    let jitterIndex = UInt32(self.jitterFrameID % 32 + 1)
    
    // Return Halton samples (+/- 0.5, +/- 0.5) that represent offsets of up to
    // half a pixel.
    let x = halton(index: jitterIndex, base: 2) - 0.5
    let y = halton(index: jitterIndex, base: 3) - 0.5
    
    // We're not sampling textures or working with multiple coordinate spaces.
    // No need to flip the Y coordinate to match another coordinate space.
    return SIMD2(x, y)
  }
  
  func upscale() {
    
  }
}


