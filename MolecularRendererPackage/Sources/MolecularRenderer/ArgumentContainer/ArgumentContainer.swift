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
  var jitterFrameID: Int = .zero
  var upscaleFactor: Int = .zero
  
  // Camera state variables.
  var currentCamera: CameraArguments?
  var previousCamera: CameraArguments?
  
  // Time state variables.
  var time: MRTime?
  
  var upscaledTextureSize: Int {
    intermediateTextureSize * upscaleFactor
  }
}

extension ArgumentContainer {
  // Write current -> previous after the frame finishes.
  mutating func registerCompletedFrame() {
    previousCamera = currentCamera
    currentCamera = nil
    time = nil
  }
}
