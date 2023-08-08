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
    
    #if true
    //    self.atomProvider = OctaneReference().provider
    //    self.atomProvider = DiamondoidCollision().provider
    self.atomProvider = VdwOscillator().provider
    
//    serializer.save(
//      fileName: "SavedSimulation",
//      provider: atomProvider as! OpenMM_AtomProvider)
    #else
    let simulation = serializer.load(fileName: "SavedSimulation")
    self.atomProvider = SimulationAtomProvider(simulation: simulation)
    
    if offline {
      renderSimulation(simulation)
    }
    #endif
  }
}

extension Renderer {
  func renderSimulation(
    _ simulation: MRSimulation,
    psPerSecond: Double = 2.0
  ) {
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
      
      var position: SIMD3<Float>
      var rotation: simd_float3x3
      
      do {
        let azimuth: Double = 1.0 * Double.pi / 2
        
        let x: SIMD2<Double> = .init(azimuth / .pi, 0)
        var sinvals: SIMD2<Double> = .zero
        var cosvals: SIMD2<Double> = .zero
        _simd_sincospi_d2(x, &sinvals, &cosvals)
        
        let sina = Float(sinvals[0])
        let cosa = Float(cosvals[0])
        let sinb = Float(sinvals[1])
        let cosb = Float(cosvals[1])
        
        // The azimuth rotation matrix is:
        let M_a = simd_float3x3(SIMD3(cosa, 0, sina),
                                SIMD3(0, 1, 0),
                                SIMD3(-sina, 0, cosa))
          .transpose // simd and Metal use the column-major format

        // The zenith rotation matrix is:
        let M_b = simd_float3x3(SIMD3(1, 0, 0),
                                SIMD3(0, cosb, -sinb),
                                SIMD3(0, sinb, cosb))
          .transpose // simd and Metal use the column-major format
        
        position = [5, 1.8, 1.8]
        rotation = M_a * M_b
      }
      
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
    print("Expected ETA: \(numFrames / 4) - \(numFrames) seconds.")
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
