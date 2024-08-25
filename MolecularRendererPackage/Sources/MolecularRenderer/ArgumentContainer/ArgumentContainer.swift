//
//  ArgumentContainer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

// Finite state machine that encapsulates the argument state.
struct ArgumentContainer {
  // Render state variables.
  var intermediateTextureSize: Int = .zero
  var upscaleFactor: Int = .zero
  var frameID: Int = .zero
  var upscaledTextureSize: Int {
    intermediateTextureSize * upscaleFactor
  }
  
  // Atom state variables.
  var currentAtoms: [SIMD4<Float>] = []
  var previousAtoms: [SIMD4<Float>] = []
  
  // Camera state variables.
  var currentCamera: CameraArguments?
  var previousCamera: CameraArguments?
  
  // Time state variables.
  var time: MRTime?
  var useMotionVectors: Bool?
}

extension ArgumentContainer {
  mutating func registerCompletedFrame() {
    // Increment the frame counter.
    frameID += 1
    
    previousAtoms = currentAtoms
    currentAtoms = []
    
    previousCamera = currentCamera
    currentCamera = nil
    
    time = nil
    useMotionVectors = nil
  }
}
