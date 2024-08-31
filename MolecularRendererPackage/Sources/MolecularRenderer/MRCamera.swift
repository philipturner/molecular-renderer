//
//  MRCamera.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
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
