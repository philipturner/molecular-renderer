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
  var serializer: Serializer!
  
  init(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.eventTracker = coordinator.eventTracker
    MRSetFrameRate(120)
    initOpenMM()
    
    let url =  Bundle.main.url(
      forResource: "MolecularRendererGPU", withExtension: "metallib")!
    self.renderingEngine = MRRenderer(
      metallibURL: url,
      width: Int(ContentView.size),
      height: Int(ContentView.size),
      upscaleFactor: ContentView.upscaleFactor)
    
    self.styleProvider = NanoStuff()
    self.serializer = Serializer(
      renderer: self,
      path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
    
    let figure = Nanosystems.Chapter4.Figure3()
    var diamondoid = figure.a
    diamondoid.center()
    
    #if true
    // TODO: Test the point where torsions and/or angles forces start to break
    // the stability of the simulation.
    let simulator = MM4(diamondoid: diamondoid)
    do {
      let field = rotationVectorField(
        angularSpeedInRadPerPs: 0, origin: .zero, axis: [0, 1, 0])
      simulator.velocityVectorField(field)
      
//      // TODO: Extract this into a utility function.
//      let angularSpeedInRadPerPs: Float = 1
//      let center: SIMD3<Float> = .zero
//      
//      // TODO: Try rotation around the Y axis for octane.
//      let axis: SIMD3<Float> = [0, 0, 1]
//      let rotation = simd_quatf(angle: .pi / 4, axis: axis)
//      
//      simulator.velocityVectorField { _, position in
//        let delta = position - center
//        let radius = length(delta)
//        var direction = normalize(delta)
//        direction = simd_act(rotation, direction)
//        
//        let speed = angularSpeedInRadPerPs * radius
//        return direction * speed
//      }
    }
    simulator.simulate(ps: 10)
    
    self.atomProvider = simulator.provider
    serializer.save(
      fileName: "Octane",
      provider: atomProvider as! OpenMM_AtomProvider)
    #else
    let simulation = serializer.load(fileName: "Octane")
    self.atomProvider = SimulationAtomProvider(simulation: simulation)
    #endif
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

