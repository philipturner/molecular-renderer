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
    let irlTime = MRTime(
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
    let animationTime = MRTime(
      absolute: animationFrameID,
      relative: animationDelta,
      frameRate: ContentView.frameRate)
    
    let playerState = eventTracker.playerState
    let progress = eventTracker.fovHistory.progress
    let fov = playerState.fovDegrees(progress: progress)
    var rotation: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
    
    let (azimuth, zenith) = playerState.orientations
    rotation = PlayerState.rotation(azimuth: azimuth, zenith: zenith)
    
    let camera = MRCamera(
      position: playerState.position,
      rotation: rotation,
      fovDegrees: fov)
    
    self.prepareRendering(
      animationTime: animationTime,
      camera: camera,
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
      
      let time = MRTime(
        absolute: frameID * framesPerFrame,
        relative: framesPerFrame,
        frameRate: 100 * framesPerFrame)
      let rotation = PlayerState.rotation(azimuth: 0, zenith: 0)
      let camera = MRCamera(
        position: [0, 0, 0],
        rotation: rotation,
        fovDegrees: 90)
      
      self.prepareRendering(
        animationTime: time,
        camera: camera,
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
    animationTime: MRTime,
    camera: MRCamera,
    frameID: Int,
    framesPerSecond: Int
  ) {
    renderingEngine.setTime(animationTime)
    
    var lights: [MRLight] = []
    let cameraLight = MRLight(
      origin: camera.position,
      diffusePower: 1, specularPower: 1)
    lights.append(cameraLight)
    renderingEngine.setCamera(camera)
    renderingEngine.setLights(lights)
  }
}
