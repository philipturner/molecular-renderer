//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import AppKit
import Atomics
import Metal
import MolecularRenderer
import simd

class Renderer {
  // Connection to Vsync.
  var view: RendererView
  var layer: CAMetalLayer
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  
  var renderer: MRRenderer!
  
  var startTimeStamp: CVTimeStamp?
  var previousTimeStamp: CVTimeStamp?
  var eventTracker: EventTracker {
    view.coordinator.eventTracker
  }
  
  // Data for robustly synchronizing with the refresh rate.
  var currentRefreshRate: ManagedAtomic<Int> = .init(0)
  var uniqueFrameID: Int = 0 // for random numbers
  var frameID: Int = 0
  var adjustedFrameID: Int = -1
  var sustainedMisalignment: Int = 0
  var sustainedMisalignmentDuration: Int = 0
  var sustainedAlignmentDuration: Int = 0
  static let debuggingFrameRate = false
  static let logFrameStutters = false
  static let frameRateBasis: Int = 120
  
  // Both modes currently use the `StaticAtomProvider` API. Once we start using
  // OpenMM in real-time, we should create the `DynamicAtomProvider` API. We can
  // develop the API beforehand using `NobleGasSimulator`.
  enum RenderingMode: Equatable {
    // Generated procedurally or read from a file.
    case `static`
    
    // Visualize a noble gas simulation running in real-time.
    case molecularSimulation
  }
  static let renderingMode: RenderingMode = .molecularSimulation
  
  // Geometry providers.
  var staticAtomProvider: MRStaticAtomProvider!
  var staticStyleProvider: MRStaticStyleProvider!
//  var nobleGasSimulator: NobleGasSimulator!
  var dynamicAtomProvider: OpenMM_DynamicAtomProvider!
  
  // NOTE: You need to give the app permission to view this file.
  static let adamantaneHabToolURL: URL = {
    let fileName = "adamantane-thiol-Hab-tool.pdb"
    let folder = "/Users/philipturner/Documents/OpenMM/Renders/Imports"
    return URL(filePath: folder + "/" + fileName)
  }()
  static let initialPlayerPosition: SIMD3<Float> = [0, 0, 1]
  
  init(view: RendererView) {
    self.view = view
    self.layer = view.layer as! CAMetalLayer
    self.currentRefreshRate.store(
      NSScreen.main!.maximumFramesPerSecond, ordering: .relaxed)
    
    let url =  Bundle.main.url(
      forResource: "MolecularRendererGPU", withExtension: "metallib")!
    let width = Int(ContentView.size)
    let height = Int(ContentView.size)
    self.renderer = MRRenderer(
      metallibURL: url, width: width, height: height)
    
    self.staticStyleProvider = ExampleStyles.NanoStuff()
    switch Self.renderingMode {
    case .static:
      self.staticAtomProvider = ExampleProviders.adamantaneHabTool(
        styleProvider: staticStyleProvider)
    case .molecularSimulation:
      self.dynamicAtomProvider = OpenMM_DynamicAtomProvider(
        psPerStep: 0.004, stepsPerFrame: 10, styles: staticStyleProvider.styles,
        elements: [18, 18, 18])
      
      initOpenMM()
      simulateArgon(provider: dynamicAtomProvider)
      
      self.dynamicAtomProvider.logReplaySpeed(
        framesPerSecond: Renderer.frameRateBasis)
      exit(0)
    }
    
    
  }
}

extension NSScreen {
  var screenNumber: UInt32 {
    (self.deviceDescription[
      NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber).uint32Value
  }
}

// Code for handling the frame rate.
extension Renderer {
  // Called at the beginning of each screen refresh.
  func vsyncHandler(
    _ displayLink: CVDisplayLink,
    _ now: UnsafePointer<CVTimeStamp>,
    _ outputTime: UnsafePointer<CVTimeStamp>,
    _ flagsIn: CVOptionFlags,
    _ flagsOut: UnsafeMutablePointer<CVOptionFlags>
  ) -> Int32 {
    // `now` is not really helpful, except for detecting stutters.
    // `output` is what you aim to render.
    let currentTimeStamp = outputTime.pointee
    if let previousTimeStamp = previousTimeStamp {
      let deltaFrames = frames(start: previousTimeStamp, end: currentTimeStamp)
      let threshold = Double(frameStep()) * 1.5
      if deltaFrames > threshold {
        if Renderer.logFrameStutters {
          print(
            "Frame stutter @ \(Date()): \(String(format: "%.2f", deltaFrames))")
        }
      }
    }
    previousTimeStamp = currentTimeStamp
    
    if startTimeStamp == nil {
      self.startTimeStamp = currentTimeStamp
    }
    
    self.update()
    return kCVReturnSuccess
  }
  
  func frames(start: CVTimeStamp, end: CVTimeStamp) -> Double {
#if arch(arm64)
    let ticksPerSecond: Int = 24 * 1000 * 1000
    let ticksPerFrame = ticksPerSecond / Renderer.frameRateBasis
#else
#error("This does not work on x86.")
#endif
    
    let deltaTicks = max(0, Int(end.hostTime) - Int(start.hostTime))
    return Double(deltaTicks) / Double(ticksPerFrame)
  }
  
  func seconds(start: CVTimeStamp, end: CVTimeStamp) -> Double {
#if arch(arm64)
    let ticksPerSecond: Int = 24 * 1000 * 1000
#else
#error("This does not work on x86.")
#endif
    
    let deltaTicks = max(0, Int(end.hostTime) - Int(start.hostTime))
    return Double(deltaTicks) / Double(ticksPerSecond)
  }
  
  // Time per frame in multiples of 120 Hz.
  func frameStep() -> Int {
    let current = currentRefreshRate.load(ordering: .relaxed)
    return max(Renderer.frameRateBasis / current, 1)
  }
  
  // Returns the frame delta.
  func updateFrameID() -> Int {
    uniqueFrameID += 1
    frameID += 1
    
    let previousFrameID = adjustedFrameID
    var nextFrameID = previousFrameID
    var targetFrameID = Int(rint(
      frames(start: startTimeStamp!, end: previousTimeStamp!)))
    let step = frameStep()
    
    // Despite my best efforts, this is still much less robust on 60 Hz than on
    // 120 Hz. Porting to lower refresh-rate monitors is not a priority.
    while nextFrameID % step > 0 {
      nextFrameID -= 1
    }
    while targetFrameID % step > 0 {
      targetFrameID -= 1
    }
    nextFrameID += step
    
    if abs(targetFrameID - nextFrameID) >= 2 * step {
      // Exponentially gravitate toward the correct position.
      // This may become unstable in certain ill-conditioned situations.
      if Renderer.debuggingFrameRate {
        print("Correcting misalignment by / 2")
      }
      nextFrameID += (targetFrameID - nextFrameID) / 2
    } else if abs(targetFrameID - nextFrameID) == step {
      // Wait a while to smooth out noise.
      if sustainedMisalignmentDuration >= 10 ||
         sustainedAlignmentDuration >= 10 {
        if Renderer.debuggingFrameRate {
          print("Correcting misalignment by +/- 1")
        }
        nextFrameID = targetFrameID
      }
    }
    
    if targetFrameID != nextFrameID {
      sustainedAlignmentDuration = 0
      let delta = targetFrameID - nextFrameID
      if delta == sustainedMisalignment {
        sustainedMisalignmentDuration += 1
      } else {
        sustainedMisalignment = delta
        sustainedMisalignmentDuration = 0
      }
    } else {
      sustainedMisalignment = 0
      sustainedMisalignmentDuration = 0
      sustainedAlignmentDuration += 1
    }
    adjustedFrameID = nextFrameID
    
    let frameDelta = nextFrameID - previousFrameID
    self.eventTracker.update(frameDelta: frameDelta)
    
    if Renderer.debuggingFrameRate {
      print(
        nextFrameID - previousFrameID, targetFrameID - nextFrameID,
        sustainedMisalignment, sustainedMisalignmentDuration,
        sustainedAlignmentDuration, currentRefreshRate.load(ordering: .relaxed))
    }
    return frameDelta
  }
}

extension Renderer {
  func update() {
    self.renderSemaphore.wait()
//    let frameDelta = self.updateFrameID()
    _ = self.updateFrameID()
    do {
      // Do not simulate while the crosshair is active.
      let eventTracker = self.view.coordinator.eventTracker!
      if !eventTracker.crosshairActive.load(ordering: .relaxed),
         Self.renderingMode == .molecularSimulation {
        // Run the simulator synchronously.
//        self.nobleGasSimulator.updateResources(frameDelta: frameDelta)
        self.dynamicAtomProvider.nextFrame()
      }
    }
    
    let atoms: [MRAtom]
    switch Self.renderingMode {
    case .static:
      atoms = staticAtomProvider.atoms
    case .molecularSimulation:
//      atoms = self.nobleGasSimulator.getAtoms()
      atoms = dynamicAtomProvider.atoms
    }
    struct TempAtomProvider: MRStaticAtomProvider {
      var atoms: [MRAtom]
    }
    renderer.setStaticGeometry(
      atomProvider: TempAtomProvider(atoms: atoms),
      styleProvider: staticStyleProvider)
    
    let playerState = self.eventTracker.playerState
    let (azimuth, zenith) = playerState.rotations
    let progress = self.eventTracker.sprintingHistory.smoothedProgress()
    renderer.setCamera(
      fovDegrees: playerState.fovDegrees(progress: progress),
      position: playerState.position,
      rotation: azimuth * zenith,
      lightPower: Float16(staticStyleProvider.lightPower),
      raySampleCount: 8)
    
    renderer.render(layer: view.metalLayer) { [self] _ in
      renderSemaphore.signal()
    }
  }
}
