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
    let upscaleFactor: Int? = ContentView.upscaleFactor
    let offline: Bool = false
    #else
    let upscaleFactor: Int? = nil
    let offline: Bool = true
    fatalError("Haven't set up workflow for offline rendering.")
    #endif
    
    let url = Bundle.main.url(
      forResource: "MolecularRendererGPU", withExtension: "metallib")!
    self.renderingEngine = MRRenderer(
      metallibURL: url,
      width: Int(ContentView.size),
      height: Int(ContentView.size),
      upscaleFactor: upscaleFactor,
      offline: offline)
    self.gifSerializer = GIFSerializer(
      path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
    self.serializer = Serializer(
      renderer: self,
      path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
    self.styleProvider = NanoStuff()
    initOpenMM()
    
    #if false
    //    self.atomProvider = OctaneReference().provider
    //    self.atomProvider = DiamondoidCollision().provider
    self.atomProvider = VdwOscillator().provider
    
    serializer.save(
      fileName: "SavedSimulation",
      provider: atomProvider as! OpenMM_AtomProvider)
    #else
    let simulation = serializer.load(fileName: "SavedSimulation")
    self.atomProvider = SimulationAtomProvider(simulation: simulation)
    #endif
  }
}

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
    
    renderingEngine.setGeometry(
      time: animationTime,
      atomProvider: &atomProvider,
      styleProvider: styleProvider)
    
    let progress = self.eventTracker.fovHistory.progress
    let playerState = self.eventTracker.playerState
    let (azimuth, zenith) = playerState.rotations
    
    let rotation = azimuth * zenith
    var lights: [MRLight] = []
    
    #if true
    let offsetXY: Float = 0.00
    let offsetZ: Float = 0.00
    let offset = rotation * [offsetXY, offsetXY, -offsetZ]
    let lightPosition = playerState.position + offset
    let cameraLight = MRLight(
      origin: lightPosition, diffusePower: 1, specularPower: 1)
    lights.append(cameraLight)
    #else
    let cameraLight = MRLight(
      origin: playerState.position, diffusePower: 0.3, specularPower: 0.3)
    lights.append(cameraLight)
    
    let sunLight = MRLight(
      origin: [400, 1000, 400], diffusePower: 1, specularPower: 1)
    lights.append(sunLight)
    #endif
    
    let quality = MRQuality(
      minSamples: 3, maxSamples: 7, qualityCoefficient: 30)
    renderingEngine.setCamera(
      fovDegrees: playerState.fovDegrees(progress: progress),
      position: playerState.position,
      rotation: rotation,
      lights: lights,
      quality: quality)
    
    let layer = coordinator.view.metalLayer!
    renderingEngine.render(layer: layer) { [self] _ in
      renderSemaphore.signal()
    }
  }
}

