//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import AppKit
import Atomics
import KeyCodes
import Metal
import MolecularRenderer
import OpenMM
import simd

class Renderer {
  unowned let coordinator: Coordinator
  unowned let eventTracker: EventTracker
  
  // Rendering resources.
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  var renderingEngine: MRRenderer!
  
  // Geometry providers.
  var atomProvider: MRAtomProvider!
  var styleProvider: MRAtomStyleProvider!
  var animationFrameID: Int = 0
  var gifSerializer: GIFSerializer!
  var serializer: Serializer!
  
  init(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.eventTracker = coordinator.eventTracker
    
    #if true
    let imageSize = Int(ContentView.size)
    let upscaleFactor: Int? = ContentView.upscaleFactor
    let offline: Bool = Bool.random() ? false : false
    #else
    let imageSize = Int(640)
    let upscaleFactor: Int? = nil
    let offline: Bool = Bool.random() ? true : true
    #endif
    
    let url = Bundle.main.url(
      forResource: "MolecularRendererGPU", withExtension: "metallib")!
    self.renderingEngine = MRRenderer(
      metallibURL: url,
      width: imageSize,
      height: imageSize,
      upscaleFactor: upscaleFactor,
      offline: offline)
    self.gifSerializer = GIFSerializer(
      path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
    self.serializer = Serializer(
      renderer: self,
      path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
    self.styleProvider = NanoStuff()
    initOpenMM()
    
    eventTracker.playerState.position = [0, 2.5, 10]
    
    #if true
    //    self.atomProvider = OctaneReference().provider
    //    self.atomProvider = DiamondoidCollision().provider
    self.atomProvider = VdwOscillator().provider
    
//    serializer.save(
//      fileName: "SavedSimulation-9",
//      provider: atomProvider as! OpenMM_AtomProvider)
    #else
    let simulation = serializer.load(fileName: "SavedSimulation-9")
    self.atomProvider = SimulationAtomProvider(simulation: simulation)
    
    if offline {
      renderSimulation(simulation)
    }
    #endif
  }
}

extension Renderer {
  func renderSimulation(
    _ simulation: MRSimulation
  ) {
    let psPerSecond: Double = 50.0 / 5
    
    let fsPerFrame = simulation.frameTimeInFs
    var framesPerFrame_d = psPerSecond * 1000 / 20 / fsPerFrame
    if abs(framesPerFrame_d - rint(framesPerFrame_d)) < 0.001 {
      framesPerFrame_d = rint(framesPerFrame_d)
    } else {
      fatalError(
        "Indivisible playback speed: \(psPerSecond) / 20 / \(fsPerFrame)")
    }
    let framesPerFrame = Int(framesPerFrame_d)
    
    let numFrames = simulation.frameCount / framesPerFrame
    for frameID in 0..<numFrames {
      print("Frame ID: \(frameID)")
      self.renderSemaphore.wait()
      
      let time = MRTimeContext(
        absolute: frameID * framesPerFrame,
        relative: framesPerFrame,
        frameRate: 20 * framesPerFrame)
      
      var position: SIMD3<Float> = [0, 2.5, 10]
      var rotation = PlayerState.makeRotation(azimuth: 0)
      
      // Programmatically control the camera position.
      #if true
      do {
        let framesPerSecond: Int = 20
        let period: Float = 10
        let rotationCenter: SIMD3<Float> = [0, 6, 6] * 0.357
        let radius: Float = 10
        
        var angle = Float(frameID) / Float(framesPerSecond)
        angle /= period
        angle *= 2 * .pi
        
        let quaternion = simd_quatf(angle: -angle, axis: [0, 1, 0])
        let delta = simd_act(quaternion, [0, 0, 1])
        position = rotationCenter + normalize(delta) * radius
        rotation = PlayerState.makeRotation(azimuth: Double(-angle))
      }
      #endif
      
      self.prepareRendering(
        animationTime: time,
        fov: 90,
        position: position,
        rotation: rotation)
      
      renderingEngine.render { pixels in
        self.gifSerializer.addImage(pixels: pixels)
        self.renderSemaphore.signal()
      }
    }
    renderingEngine.stopRendering()
    
    // The encoder from the Swift GIF package is very slow; we might need to
    // fork the repository and speed it up. The encoding is faster when the
    // image isn't completely blank.
    print("ETA: \(numFrames / 4) - \(numFrames) seconds.")
    gifSerializer.save(fileName: "SavedSimulation")
    print("Checkpoint 3")
    print("Saved the production render.")
    print("Checkpoint 4")
    exit(0)
  }
  
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
    var position: SIMD3<Float>
    var rotation: simd_float3x3
    
    position = playerState.position
    let (azimuth, zenith) = playerState.rotations
    rotation = azimuth * zenith
    
    // Programmatically control the camera position.
    #if true
    do {
      let framesPerSecond: Int = 120
      let period: Float = 10
      let rotationCenter: SIMD3<Float> = [0, 6, 6] * 0.357
      let radius: Float = 10
      
      var angle = Float(frameID) / Float(framesPerSecond)
      angle /= period
      angle *= 2 * .pi
      
      let quaternion = simd_quatf(angle: -angle, axis: [0, 1, 0])
      let delta = simd_act(quaternion, [0, 0, 1])
      position = rotationCenter + normalize(delta) * radius
      rotation = PlayerState.makeRotation(azimuth: Double(-angle))
    }
    #endif
    
    self.prepareRendering(
      animationTime: animationTime,
      fov: fov,
      position: position,
      rotation: rotation)
    
    let layer = coordinator.view.metalLayer!
    renderingEngine.render(layer: layer) {
      self.renderSemaphore.signal()
    }
  }
  
  private func prepareRendering(
    animationTime: MRTimeContext,
    fov: Float,
    position: SIMD3<Float>,
    rotation: simd_float3x3
  ) {
    renderingEngine.setGeometry(
      time: animationTime,
      atomProvider: &atomProvider,
      styleProvider: styleProvider)
    
    var lights: [MRLight] = []
    let cameraLight = MRLight(
      origin: position, diffusePower: 1, specularPower: 1)
    lights.append(cameraLight)
    
    let quality = MRQuality(
      minSamples: 3, maxSamples: 7, qualityCoefficient: 30)
    renderingEngine.setCamera(
      fovDegrees: fov,
      position: position,
      rotation: rotation,
      lights: lights,
      quality: quality)
  }
}
