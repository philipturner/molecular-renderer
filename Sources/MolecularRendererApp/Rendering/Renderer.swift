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
    
    #if false
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
    
//    let url2 = URL(filePath: "/Users/philipturner/Desktop/armchair-graphane-W-structure.pdb")
    
//    let url2 = URL(filePath: "/Users/philipturner/Desktop/hydrocarbon-sleeve.pdb")
//    let parsed = PDBParser(url: url2, hasA1: true)
    
//    let parsed = NanoEngineerParser(
//      partLibPath: "bearings/Hydrocarbon Strained Sleeve Bearing.mmp")
//    let centers = parsed._atoms.compactMap { atom -> SIMD3<Float>? in
//      if atom.element == 6 {
//        return atom.origin
//      } else {
//        return nil
//      }
//    }
////
//    var diamondoid = Diamondoid(carbonCenters: centers)
//    diamondoid.translate(offset: -diamondoid.createCenterOfMass())
//    diamondoid.rotate(angle: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]))
//    
//    var simulation = MM4(diamondoid: diamondoid, fsPerFrame: 20)
//    let ranges = simulation.rigidBodies
//    let state = simulation.context.state(types: [.positions, .velocities])
//    let statePositions = state.positions
//    let stateElements = simulation.provider.elements
//    var rigidBodies = ranges.map { range -> Diamondoid in
//      var centers: [SIMD3<Float>] = []
//      for index in range {
//        guard stateElements[index] == 6 else {
//          continue
//        }
//        
//        let position = statePositions[index]
//        centers.append(SIMD3(position))
//      }
//      return Diamondoid(carbonCenters: centers)
//    }
//    print(rigidBodies.count)
//    print(rigidBodies[0].atoms.count)
//    print(rigidBodies[1].atoms.count)
//    
//    rigidBodies[1].angularVelocity = simd_quatf(angle: 1, axis: [0, 0, 1])
//    
//    simulation = MM4(diamondoids: rigidBodies, fsPerFrame: 20)
//    simulation.simulate(ps: 15)
//    
//    
//    
//    self.atomProvider = simulation.provider
//    serializer.save(fileName: "Strained Shell Bearing", provider: simulation.provider)
    
    
//    self.atomProvider = ArrayAtomProvider(diamondoid.atoms)
//      
////    }
//    let provider = ArrayAtomProvider(centers.map {
//      MRAtom(origin: $0, element: 6)
//    })
//    self.atomProvider = provider
    
    
    
    #if false
    //    self.atomProvider = OctaneReference().provider
    //    self.atomProvider = DiamondoidCollision().provider
    self.atomProvider = VdwOscillator().provider
    
//    serializer.save(
//      fileName: "SavedSimulation-10",
//      provider: atomProvider as! OpenMM_AtomProvider)
    #else
    let simulation = serializer.load(fileName: "Strained Shell Bearing")
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
//    let psPerSecond: Double = 40.0
    let psPerSecond: Double = 2.4
    
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
      
      var position: SIMD3<Float> = [0, 0, 10]
      var rotation = PlayerState.makeRotation(azimuth: 0)
      
      // Programmatically control the camera position.
      #if true
      do {
        let framesPerSecond: Int = 20
        let period: Float = 12.5 // 25
//        let rotationCenter: SIMD3<Float> = [0, 6, 6] * 0.357
        let rotationCenter: SIMD3<Float> = [0, 0, 0] // [1.0158, 0, 0]
        let radius: Float = 3 // 10
        
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
      let period: Float = 15 // 30
//      let rotationCenter: SIMD3<Float> = [0, 6, 6] * 0.357
      let rotationCenter: SIMD3<Float> =  [0, 0, 0] // [1.0158, 0, 0]
      let radius: Float = 3 // 10
      
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
