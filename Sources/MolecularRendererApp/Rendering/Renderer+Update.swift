//
//  Renderer+Update.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/29/23.
//

import Foundation
import MolecularRenderer
import simd

extension Renderer {
  func update() {
    self.renderSemaphore.wait()
    
    let frameDelta = coordinator.vsyncHandler.updateFrameID()
    let frameID = coordinator.vsyncHandler.frameID
    let irlTime = MRTimeContext(
      absolute: frameID,
      relative: frameDelta,
      frameRate: ContentView.frameRate)
    eventTracker.update(time: irlTime)
    
    var animationDelta: Int
    if eventTracker[.keyboardP].pressed {
      animationDelta = frameDelta
    } else {
      animationDelta = 0
    }
    if eventTracker[.keyboardR].pressed {
      animationDelta = 0
      animationFrameID = 0
    }
    animationFrameID += animationDelta
    let animationTime = MRTimeContext(
      absolute: animationFrameID,
      relative: animationDelta,
      frameRate: ContentView.frameRate)
    
    let playerState = eventTracker.playerState
    let progress = eventTracker.fovHistory.progress
    let fov = playerState.fovDegrees(progress: progress)
    
    let (azimuth, zenith) = playerState.rotations
    self.prepareRendering(
      animationTime: animationTime,
      fov: fov,
      position: playerState.position,
      rotation: azimuth * zenith,
      frameID: frameID,
      framesPerSecond: 120)
    
    let layer = coordinator.view.metalLayer!
    renderingEngine.render(layer: layer) {
      self.renderSemaphore.signal()
    }
  }
  
  func renderSimulation(
    _ simulation: MRSimulation
  ) {
    func getFramesPerFrame(psPerSecond: Double? = nil) -> Int {
      if let psPerSecond {
        let fsPerFrame = simulation.frameTimeInFs
        var framesPerFrame = psPerSecond * 1000 / 100 / fsPerFrame
        if abs(framesPerFrame - rint(framesPerFrame)) < 0.001 {
          framesPerFrame = rint(framesPerFrame)
        } else {
          fatalError(
            "Indivisible playback speed: \(psPerSecond) / 100 / \(fsPerFrame)")
        }
        return Int(framesPerFrame)
      } else {
        return 2
      }
    }
    let framesPerFrame = getFramesPerFrame()
    
    let numFrames = simulation.frameCount / framesPerFrame
    for frameID in 0..<numFrames {
      self.renderSemaphore.wait()
      let timeDouble = Double(frameID) / 100
      if frameID % 2 == 0 {
        print("Timestamp: \(String(format: "%.2f", timeDouble))")
      }
      
      let time = MRTimeContext(
        absolute: frameID * framesPerFrame,
        relative: framesPerFrame,
        frameRate: 100 * framesPerFrame)
      
      self.prepareRendering(
        animationTime: time,
        fov: 90,
        position: [0, 0, 0],
        rotation: PlayerState.makeRotation(azimuth: 0),
        frameID: frameID,
        framesPerSecond: 100)
      
      renderingEngine.render { pixels in
        self.gifSerializer.addImage(pixels: pixels, blurFusion: 2)
        self.renderSemaphore.signal()
      }
    }
    renderingEngine.stopRendering()
  }
  
  private func prepareRendering(
    animationTime: MRTimeContext,
    fov: Float,
    position: SIMD3<Float>,
    rotation: simd_float3x3,
    frameID: Int,
    framesPerSecond: Int
  ) {
    renderingEngine.setGeometry(
      time: animationTime,
      atomProvider: &atomProvider,
      styleProvider: styleProvider,
      useMotionVectors: animationTime.absolute.frames > 0)
    
    var _fov = fov
    var _position = position
    var _rotation = rotation
    if Self.programCamera {
      _fov = 90
      _position = [3, -4.5, 5]
      _rotation = _rotation * simd_float3x3(
        SIMD3(1, 0, 0),
        SIMD3(0, cos(60 * .pi / 180), -sin(60 * .pi / 180)),
        SIMD3(0, sin(60 * .pi / 180), cos(60 * .pi / 180))).transpose
      
      //      let period: Float = .greatestFiniteMagnitude
      //      let rotationCenter: SIMD3<Float> =  [0, 0, 0]
      //      let radius: Float = 2.5
      //
      //      var angle = Float(frameID) / Float(framesPerSecond)
      //      angle /= period
      //      angle *= 2 * .pi
      //
      //      let quaternion = Quaternion<Float>(angle: -angle, axis: [0, 1, 0])
      //      let delta = simd_act(quaternion, [0, 0, 1])
      //      _position = rotationCenter + cross_platform_normalize(delta) * radius
      //      _rotation = PlayerState.makeRotation(azimuth: Double(-angle))
      
//      var rotationCenter: SIMD3<Float> =  [-2.5, 3, +4]
//      rotationCenter += 0.357 * SIMD3(3.75, 8.00, 3.75)
//
//      var angle = Float(0.125)
//      angle *= 2 * .pi
//
//      _ = Quaternion<Float>(angle: -angle, axis: [0, 1, 0])
//      _position = rotationCenter
//      _rotation = PlayerState.makeRotation(azimuth: Double(-angle))
//      _rotation = _rotation * simd_float3x3(
//        SIMD3(0, 1, 0),
//        SIMD3(-1, 0, 0),
//        SIMD3(0, 0, 1)).transpose
      
//      #if false
//      _position = [-8, 0, 8] + [3, 0, 3]
//      _rotation = PlayerState.makeRotation(
//        azimuth: Double(-45 * Double.pi / 180))
//      #else
//      let zenithAngle = 40 * Float.pi / 180
//      _position = [3, 0, 3] + [4, 4, 2]
//      _rotation = PlayerState.makeRotation(
//        azimuth: Double(60 * Double.pi / 180)) * simd_float3x3(
//          SIMD3(1, 0, 0),
//          SIMD3(0, cos(zenithAngle), sin(zenithAngle)),
//          SIMD3(0, -sin(zenithAngle), cos(zenithAngle))).transpose
//      #endif
    }
    
    var lights: [MRLight] = []
    let cameraLight = MRLight(
      origin: _position, diffusePower: 1, specularPower: 1)
    lights.append(cameraLight)
    
    let quality = MRQuality(
      minSamples: 3, maxSamples: 7, qualityCoefficient: 30)
    renderingEngine.setCamera(
      fovDegrees: _fov,
      position: _position,
      rotation: _rotation,
      lights: lights,
      quality: quality)
  }
}
