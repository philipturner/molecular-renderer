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
  
  // Element state variables.
  var elementColors: [SIMD3<Float>] = []
  var elementRadii: [Float] = []
  
  // Atom state variables.
  var currentAtoms: [SIMD4<Float>] = []
  var previousAtoms: [SIMD4<Float>] = []
  
  // Camera state variables.
  var currentCamera: CameraArguments?
  var previousCamera: CameraArguments?
  
  // Time state variables.
  var currentTime: MRTime?
  var previousTime: MRTime?
}

extension ArgumentContainer {
  mutating func registerCompletedFrame() {
    // Increment the frame counter.
    frameID += 1
    
    previousAtoms = currentAtoms
    currentAtoms = []
    
    previousCamera = currentCamera
    currentCamera = nil
    
    previousTime = currentTime
    currentTime = nil
  }
}
