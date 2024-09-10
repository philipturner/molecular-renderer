//
//  ArgumentContainer+Render.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

import func Foundation.tan

// Render arguments data structure.
struct RenderArguments {
  var screenWidth: UInt16 = .zero
  var frameSeed: UInt32 = .zero
  var jitterOffsets: SIMD2<Float> = .zero
  var criticalDistance: Float = .zero
}

extension ArgumentContainer {
  func createFrameSeed() -> UInt32 {
    .random(in: 0..<UInt32.max)
  }
  
  func createJitterOffsets() -> SIMD2<Float> {
    func halton(index: Int, base: Int) -> Float {
      var result: Float = 0.0
      var fractional: Float = 1.0
      var currentIndex: Int = index
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
    let index = haltonIndex()
    
    // Return Halton samples (+/- 0.5, +/- 0.5) that represent offsets of up to
    // half a pixel.
    let x = halton(index: index, base: 2) - 0.5
    let y = halton(index: index, base: 3) - 0.5
    
    // We're not sampling textures or working with multiple coordinate spaces.
    // No need to flip the Y coordinate to match another coordinate space.
    return SIMD2(x, y)
  }
  
  func createCriticalDistance() -> Float {
    let fovRadians = currentFOVDegrees * .pi / 180
    let tangentFactor = 2 * tan(fovRadians / 2)
    let distanceInNm: Float = 1.0
    let pixelCount: Int = 150
    
    var output = distanceInNm / Float(pixelCount)
    output *= Float(renderTargetSize)
    output /= tangentFactor
    return output
  }
  
  func createRenderArguments() -> RenderArguments {
    var output = RenderArguments()
    output.screenWidth = UInt16(rayTracedTextureSize)
    output.frameSeed = createFrameSeed()
    output.jitterOffsets = createJitterOffsets()
    output.criticalDistance = createCriticalDistance()
    return output
  }
}
