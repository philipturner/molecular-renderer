//
//  ArgumentContainer+Render.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

// Render arguments data structure.
struct RenderArguments {
  var jitter: SIMD2<Float> = .zero
  var frameSeed: UInt32 = .zero
  var qualityCoefficient: Float = .zero
  var useAtomMotionVectors: Bool = false
}

extension ArgumentContainer {
  func createQualityCoefficient() -> Float {
    var screenMagnitude = Float(upscaledTextureSize)
    screenMagnitude *= screenMagnitude
    
    // Quality coefficients are calibrated against 640x640 -> 1280x1280
    // resolution.
    screenMagnitude = screenMagnitude.squareRoot() / 1280
    return 30 * screenMagnitude
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
}

extension ArgumentContainer {
  mutating func updateAtoms(provider: MRAtomProvider) {
    guard let currentTime else {
      fatalError("Time was not specified.")
    }
    
    let providerAtoms = provider.atoms(time: currentTime)
    guard providerAtoms.count > 0,
          providerAtoms.count < BVHBuilder.maxAtomCount else {
      fatalError("Atom count was invalid.")
    }
    
    currentAtoms = providerAtoms
  }
  
  func createRenderArguments() -> RenderArguments {
    var output = RenderArguments()
    output.jitter = createJitterOffsets()
    output.frameSeed = .random(in: 0..<UInt32.max)
    output.qualityCoefficient = createQualityCoefficient()
    output.useAtomMotionVectors = useAtomMotionVectors
    return output
  }
}
