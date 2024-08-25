//
//  ArgumentContainer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

/*
 
 @_alignment(16)
 struct Arguments {
   var fovMultiplier: Float
   var positionX: Float
   var positionY: Float
   var positionZ: Float
   var rotation: simd_float3x3
   var jitter: SIMD2<Float>
   var frameSeed: UInt32
   var qualityCoefficient: Float
   
   var worldOrigin: SIMD3<Int16>
   var worldDimensions: SIMD3<Int16>
   
   var previousPosition: SIMD3<Float>
   var previousRotation: simd_float3x3
   var previousFOVMultiplier: Float
 }
 
 */

// Finite state machine that encapsulates the argument state.
struct ArgumentContainer {
  // Render state variables.
  var intermediateTextureSize: Int = .zero
  var jitterFrameID: Int = .zero
  var upscaleFactor: Int = .zero
  
  // Camera state variables.
  var currentCamera: CameraArguments?
  var previousCamera: CameraArguments?
  
  var upscaledTextureSize: Int {
    intermediateTextureSize * upscaleFactor
  }
}
