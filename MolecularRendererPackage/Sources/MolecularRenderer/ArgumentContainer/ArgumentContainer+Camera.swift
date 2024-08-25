//
//  ArgumentContainer+Camera.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/24/24.
//

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

// Camera arguments data structure.
struct CameraArguments {
  var positionAndFOVMultiplier: SIMD4<Float> = .zero
  var rotationColumn1: SIMD3<Float> = .zero
  var rotationColumn2: SIMD3<Float> = .zero
  var rotationColumn3: SIMD3<Float> = .zero
}

// API for specifying camera state.
extension MRRenderer {
  public func setCamera(_ camera: MRCamera) {
    let fovMultiplier = ArgumentContainer.createFOVMultiplier(
      intermediateTextureSize: intermediateTextureSize,
      fovDegrees: camera.fovDegrees)
    
    var cameraArgs = CameraArguments()
    cameraArgs.positionAndFOVMultiplier = SIMD4(
      camera.position, fovMultiplier)
    cameraArgs.rotationColumn1 = camera.rotation.0
    cameraArgs.rotationColumn2 = camera.rotation.1
    cameraArgs.rotationColumn3 = camera.rotation.2
    
    argumentContainer.currentCamera = cameraArgs
  }
}
