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

func checkCVDisplayError(
  _ error: CVReturn,
  file: StaticString = #file,
  line: UInt = #line
) {
  if _slowPath(error != kCVReturnSuccess) {
    let message = "Encountered CVDisplay error '\(error)' at \(file):\(line)"
    print(message)
    fatalError(message, file: file, line: line)
  }
}

// TODO: Split the renderer into several files. I'm not sure how much can be
// moved into the "MolecularRenderer" library though.
class Renderer {
  // Connection to Vsync.
  var view: RendererView
  var layer: CAMetalLayer
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
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  
  // Objects to encapsulate complex operations.
  var accelBuilder: MRAccelBuilder!
  var renderer: MRRenderer!
  
  enum RenderingMode: Equatable {
    // Generated procedurally or read from a file.
    case `static`
    
    // Visualize an MD simulation running in real-time.
    case molecularSimulation
  }
  static let renderingMode: RenderingMode = .static
  
  // Variables for loading static geometry.
  var staticAtomProvider: (any MRStaticAtomProvider)!
  var staticStyleProvider = ExampleStyles.NanoStuff()
  static func createStaticAtomProvider() -> any MRStaticAtomProvider {
//    ExampleMolecules.TaggedEthylene()
//    NanoEngineerParser(partLibPath: "gears/MarkIII[k] Planetary Gear Box")
    PDBParser(url: adamantaneHabToolURL)
  }
  
  // NOTE: You need to give the app permission to view this file.
  static let adamantaneHabToolURL: URL = {
    let fileName = "adamantane-thiol-Hab-tool.pdb"
    let folder = "/Users/philipturner/Documents/OpenMM/Renders/Imports"
    return URL(filePath: folder + "/" + fileName)
  }()
  
  // Variables for controlling a real-time MD simulation.
  // TODO: Extract of these parameters into the setup of a noble gas simulator.
  // TODO: Warn that you must switch to Swift release mode to run this.
  var simulator: NobleGasSimulator!
  static let logSimulationSpeed: Bool = true
  static let initialPlayerPosition: SIMD3<Float> = [0, 0, 1]
  static let simulationID: Int = 3 // 0-2
  static let simulationSpeed: Double = 5e-12 // ps/s
  
  init(view: RendererView) {
    let eventTracker = view.coordinator.eventTracker!
    eventTracker.playerState.position = Self.initialPlayerPosition
    
    self.view = view
    self.layer = view.layer as! CAMetalLayer
    self.currentRefreshRate.store(
      NSScreen.main!.maximumFramesPerSecond, ordering: .relaxed)

    // Initialize Metal resources.
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!
    
    // Create delegate objects.
    self.accelBuilder = MRAccelBuilder(
      device: device, commandQueue: commandQueue)
    
    let provider = GlobalStyleProvider.global
    self.renderer = MRRenderer(
      device: device, commandQueue: commandQueue,
      width: Int(ContentView.size), height: Int(ContentView.size),
      atomRadii: provider.atomRadii, atomColors: provider.atomColors)
    
    switch Self.renderingMode {
    case .static:
      self.staticAtomProvider = Renderer.createStaticAtomProvider()
    case .molecularSimulation:
      self.simulator = NobleGasSimulator(
        simulationID: Self.simulationID, frameRate: Self.frameRateBasis)
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
  
  // Returns frame delta.
  func updateFrameID() -> Int {
    uniqueFrameID += 1
    frameID += 1
    
    let previousFrameID = adjustedFrameID
    var nextFrameID = previousFrameID
    var targetFrameID = Int(rint(
      frames(start: startTimeStamp!, end: previousTimeStamp!)))
    let step = frameStep()
    
    // TODO: This is still much less robust on 60 Hz than on 120 Hz.
    // Eventually, allow someone to set a custom basis besides 120 Hz. Then,
    // scale geometry loading operations by 120 / basis.
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

// Code for sending commands to the GPU.
extension Renderer {
  func update() {
    self.renderSemaphore.wait()
    let frameDelta = self.updateFrameID()
    
    do {
      // Do not simulate while the crosshair is active.
      let eventTracker = self.view.coordinator.eventTracker!
      if !eventTracker.crosshairActive.load(ordering: .relaxed),
         Self.renderingMode == .molecularSimulation {
        // Run the simulator synchronously.
        let (nsPerDay, timeTaken) = self.simulator.evolve(
          frameDelta: frameDelta, timeScale: Self.simulationSpeed)
        if Self.logSimulationSpeed {
          let nsRepr = String(format: "%.1f", nsPerDay)
          let ms = timeTaken / 1e-3
          let msRepr = String(format: "%.3f", ms)
          print("\(nsRepr) ns/day, \(msRepr) ms/frame")
        }
      }
    }
    
    if true {
      // The accelBuilder automatically caches acceleration structures, but
      // explicitly marking them as static allows it to compress the structures.
      var shouldCompact: Bool
      
      let atoms: [MRAtom]
      switch Self.renderingMode {
      case .static:
        atoms = staticAtomProvider.atoms
        shouldCompact = true
      case .molecularSimulation:
        atoms = self.simulator.getAtoms()
        shouldCompact = false
      }
      
      struct TempAtomProvider: MRStaticAtomProvider {
        var atoms: [MRAtom]
      }
      
      // TODO: Remove the accelBuilder from 'Renderer' and put it in 'MRRenderer'.
      renderer.setStaticGeometry(
        atomProvider: TempAtomProvider(atoms: atoms),
        styleProvider: staticStyleProvider,
        shouldCompact: shouldCompact,
        accelBuilder: accelBuilder)
    }
    
    do {
      // Image width before upscaling.
      let imageWidth = ContentView.size / 2
      let playerState = self.eventTracker.playerState
      
      let fovMultiplier = playerState.fovMultiplier(
        imageWidth: Int(imageWidth), frameID: frameID)
      let (azimuth, zenith) = playerState.rotations
      renderer.setCamera(
        fovMultiplier: Float(fovMultiplier),
        position: playerState.position,
        rotation: azimuth * zenith,
        lightPower: GlobalStyleProvider.global.lightPower)
    }
    renderer.render(
      accelBuilder: accelBuilder,
      layer: view.metalLayer
    ) { [self] _ in
      renderSemaphore.signal()
    }
  }
}
