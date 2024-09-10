//
//  ArgumentContainer+Camera.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

import func Foundation.tan

// Camera arguments data structure.
struct CameraArguments {
  var position: SIMD3<Float> = .zero
  var rotationColumn1: SIMD3<Float> = .zero
  var rotationColumn2: SIMD3<Float> = .zero
  var rotationColumn3: SIMD3<Float> = .zero
  var fovMultiplier: Float = .zero
}

extension ArgumentContainer {
  func createFOVMultiplier() -> Float {
    let fovRadians = currentFOVDegrees * .pi / 180
    let tangentFactor = 2 * tan(fovRadians / 2)
    return tangentFactor / Float(rayTracedTextureSize)
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
    argumentContainer.currentFOVDegrees = camera.fovDegrees
    
    var cameraArgs = CameraArguments()
    cameraArgs.position = camera.position
    cameraArgs.rotationColumn1 = camera.rotation.0
    cameraArgs.rotationColumn2 = camera.rotation.1
    cameraArgs.rotationColumn3 = camera.rotation.2
    cameraArgs.fovMultiplier = argumentContainer.createFOVMultiplier()
    argumentContainer.currentCamera = cameraArgs
  }
}
