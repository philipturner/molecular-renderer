//
//  ArgumentContainer+Render.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

// Render arguments data structure.
struct RenderArguments {
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
    //
    // TODO: Check whether the FOV factors into the quality coefficient. This
    // may be the source of visual artifacts / unexpected behavior.
    screenMagnitude = screenMagnitude.squareRoot() / 1280
    return 30 * screenMagnitude
  }
  
  func createRenderArguments() -> RenderArguments {
    var output = RenderArguments()
    output.frameSeed = .random(in: 0..<UInt32.max)
    output.qualityCoefficient = createQualityCoefficient()
    output.useAtomMotionVectors = useAtomMotionVectors
    return output
  }
}
