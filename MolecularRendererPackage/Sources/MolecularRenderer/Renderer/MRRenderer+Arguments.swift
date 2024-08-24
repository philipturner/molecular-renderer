//
//  MRRenderer+Arguments.swift
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
  func createCameraArguments() {
    
  }
}

// Camera arguments data structure.
struct CameraArguments {
  var positionAndFOVMultiplier: SIMD4<Float>
  var rotationColumn1: SIMD3<Float>
  var rotationColumn2: SIMD3<Float>
  var rotationColumn3: SIMD3<Float>
}

// BVH arguments data structure.
struct BVHArguments {
  var worldOrigin: SIMD3<Int16>
  var worldDimensions: SIMD3<Int16>
}

// Render arguments data structure.
struct RenderArguments {
  var jitter: SIMD2<Float>
  var frameSeed: UInt32
  var qualityCoefficient: Float
}


