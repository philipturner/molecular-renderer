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
  var atomProvider: MRAtomProvider
  var styleProvider: MRAtomStyleProvider & LightPowerProvider
  var animationFrameID: Int = 0
  
  init(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.eventTracker = coordinator.eventTracker
    
    let url =  Bundle.main.url(
      forResource: "MolecularRendererGPU", withExtension: "metallib")!
    self.renderingEngine = MRRenderer(
      metallibURL: url,
      width: Int(ContentView.size),
      height: Int(ContentView.size))
    MRSetFrameRate(120)
    
    self.styleProvider = ExampleStyles.NanoStuff()
    self.atomProvider = NanoEngineerParser(
      styleProvider: styleProvider,
      partLibPath: "others/Fine Motion Controller")
  }
}

extension Renderer {
  func update() {
    self.renderSemaphore.wait()
    
    let frameDelta = coordinator.vsyncHandler.updateFrameID()
    let frameID = coordinator.vsyncHandler.frameID
    let irlTime = MRTimeContext(absolute: frameID, relative: frameDelta)
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
      absolute: animationFrameID, relative: animationDelta)
    
    let atoms = atomProvider.atoms(time: animationTime)
    renderingEngine.setGeometry(
      time: animationTime, atoms: atoms, styles: styleProvider.styles)
    
    let progress = self.eventTracker.fovHistory.progress
    let playerState = self.eventTracker.playerState
    let (azimuth, zenith) = playerState.rotations
    renderingEngine.setCamera(
      fovDegrees: playerState.fovDegrees(progress: progress),
      position: playerState.position,
      rotation: azimuth * zenith,
      lightPower: styleProvider.lightPower,
      raySampleCount: 7)
    
    let layer = coordinator.view.metalLayer!
    renderingEngine.render(layer: layer) { [self] _ in
      renderSemaphore.signal()
    }
  }
}

