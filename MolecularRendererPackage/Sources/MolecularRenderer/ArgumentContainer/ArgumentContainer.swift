//
//  ArgumentContainer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

// We don't support Intel Macs, but they cause an unavoidable compiler error
// in SwiftPM. We work around this by making half-precision a typealias of
// something obviously wrong.
#if os(macOS) && arch(x86_64)
typealias Float16 = Float64
#endif

// Finite state machine that encapsulates the argument state.
struct ArgumentContainer {
  // Render state variables.
  var frameID: Int = .zero
  var rayTracedTextureSize: Int {
    renderTargetSize / 3
  }
  var renderTargetSize: Int = .zero
  
  // Element state variables.
  var elementColors: [SIMD3<Float16>] = []
  var elementRadii: [Float16] = []
  
  // Atom state variables.
  var previousAtoms: [SIMD4<Float>] = []
  var currentAtoms: [SIMD4<Float>] = []
  
  // Camera state variables.
  var previousCamera: CameraArguments?
  var currentCamera: CameraArguments?
  var currentFOVDegrees: Float = .zero
  
  // Time state variables.
  var previousTime: MRTime?
  var currentTime: MRTime?
}

extension ArgumentContainer {
  // Convert the colors from FP32 to FP16. We use 32-bit types in the public
  // API, to interface better with other code.
  static func createElementColors(
    _ input: [SIMD3<Float>]
  ) -> [SIMD3<Float16>] {
    var output: [SIMD3<Float16>] = []
    for atomicNumber in 0...118 {
      // Branch on whether the color was specified.
      if atomicNumber < input.count {
        let color32 = input[atomicNumber]
        let color16 = SIMD3<Float16>(color32)
        output.append(color16)
      } else {
        output.append(.zero)
      }
    }
    return output
  }
  
  // An optimization to the BVH construction requires that atoms span no
  // more than 3 small voxels in each coordinate. We must make it impossible
  // for an atom to span 4 voxels. We accomplish this restriction by clamping
  // atomic radii to slightly less than the voxel width (0.25 nm).
  static func createElementRadii(
    _ input: [Float]
  ) -> [Float16] {
    var output: [Float16] = []
    for atomicNumber in 0...118 {
      // Branch on whether the radius was specified.
      if atomicNumber < input.count {
        var radius32 = input[atomicNumber]
        radius32 = max(radius32, 0.001)
        radius32 = min(radius32, 0.249)
        
        let radius16 = Float16(radius32)
        output.append(radius16)
      } else {
        output.append(.zero)
      }
    }
    return output
  }
  
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
