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
        // DO NOT return 2 here! That is for blur fusion!
        return 1
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
      _position = [0, 0, 1]
      _rotation = matrix_identity_float3x3
    }
    
    var lights: [MRLight] = []
    let cameraLight = MRLight(
      origin: _position,
      diffusePower: 0.6, specularPower: 0.6)
    let cameraLight2 = MRLight(
      origin: _position + _rotation * [0, 0, -1],
      diffusePower: 0.4, specularPower: 0.4)
    lights.append(cameraLight)
    lights.append(cameraLight2)
    
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
