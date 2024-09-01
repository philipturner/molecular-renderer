//
//  ArgumentContainer+Camera.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

import func Foundation.tan

// Camera arguments data structure.
struct CameraArguments {
  var positionAndFOVMultiplier: SIMD4<Float> = .zero
  var rotationColumn1: SIMD3<Float> = .zero
  var rotationColumn2: SIMD3<Float> = .zero
  var rotationColumn3: SIMD3<Float> = .zero
  var jitter: SIMD2<Float> = .zero
}

extension ArgumentContainer {
  func createFOVMultiplier(fovDegrees: Float) -> Float {
    // How many pixels exist in either direction.
    let fov90Span = 0.5 * Float(intermediateTextureSize)
    
    // Larger FOV means the same ray will reach an angle farther away from the
    // center. 1 / fovSpan is larger, so fovSpan is smaller. The difference
    // should be the ratio between the tangents of the two half-angles. And
    // one side of the ratio is tan(90 / 2) = 1.0.
    let fovRadians: Float = fovDegrees * .pi / 180
    let halfAngleTangent = tan(fovRadians / 2)
    let halfAngleTangentRatio = halfAngleTangent / 1.0
    
    // Let A = fov90Span
    // Let B = pixels covered by the 45° boundary in either direction.
    // Ray = ((pixelsRight, pixelsUp) * fovMultiplier, -1)
    //
    // FOV / 2 < 45°
    // - edge of image is ray (<1, <1, -1)
    // - A = 100 pixels
    // - B = 120 pixels (off-screen)
    // - fovMultiplier = 1 / 120 = 1 / B
    // FOV / 2 = 45°
    // - edge of image is ray (1, 1, -1)
    // - fovMultiplier = unable to determine
    // FOV / 2 > 45°
    // - edge of image is ray (>1, >1, -1)
    // - A = 100 pixels
    // - B = 80 pixels (well within screen bounds)
    // - fovMultiplier = 1 / 80 = 1 / B
    
    // Next: what is B as a function of fov90Span and halfAngleTangentRatio?
    // FOV / 2 < 45°
    // - A = 100 pixels
    // - B = 120 pixels (off-screen)
    // - halfAngleTangentRatio = 0.8
    // - formula: B = A / halfAngleTangentRatio
    // FOV / 2 = 45°
    // - A = 100 pixels
    // - B = 100 pixels
    // - formula: cannot be determined
    // FOV / 2 > 45°
    // - edge of image is ray (>1, >1, -1)
    // - A = 100 pixels
    // - B = 80 pixels (well within screen bounds)
    // - halfAngleTangentRatio = 1.2
    // - formula: B = A / halfAngleTangentRatio
    //
    // fovMultiplier = 1 / B = 1 / (A / halfAngleTangentRatio)
    // fovMultiplier = halfAngleTangentRatio / fov90Span
    return halfAngleTangentRatio / fov90Span
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
  
  func createCameraArguments() -> [CameraArguments] {
    guard let currentCamera else {
      fatalError("Current camera was not specified.")
    }
    var output = [currentCamera]
    
    if let previousCamera {
      output.append(previousCamera)
    } else {
      output.append(currentCamera)
    }
    return output
  }
}

// MARK: - API

// MRCamera data structure.
public struct MRCamera {
  public var position: SIMD3<Float>
  public var rotation: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
  public var fovDegrees: Float
  
  public init(
    position: SIMD3<Float>,
    rotation: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>),
    fovDegrees: Float
  ) {
    self.position = position
    self.rotation = rotation
    self.fovDegrees = fovDegrees
  }
}

// API for specifying camera state.
extension MRRenderer {
  public func setCamera(_ camera: MRCamera) {
    var cameraArgs = CameraArguments()
    cameraArgs.rotationColumn1 = camera.rotation.0
    cameraArgs.rotationColumn2 = camera.rotation.1
    cameraArgs.rotationColumn3 = camera.rotation.2
    
    let fovMultiplier = argumentContainer.createFOVMultiplier(
      fovDegrees: camera.fovDegrees)
    cameraArgs.positionAndFOVMultiplier = SIMD4(
      camera.position, fovMultiplier)
    
    let jitter = argumentContainer.createJitterOffsets()
    cameraArgs.jitter = jitter
    
    argumentContainer.currentCamera = cameraArgs
  }
}
