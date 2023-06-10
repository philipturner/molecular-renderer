//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import AppKit
import Atomics
import Metal
import simd
import MolecularRenderer

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
  static let debuggingJitter = false
  static let logFrameStutters = false
  static let frameRateBasis: Int = 120
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var rayTracingPipeline: MTLComputePipelineState
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  
  // Memory objects for rendering.
  var styles: MTLBuffer
  
  // Cache previous arguments to generate motion vectors.
  struct Arguments {
    var position: SIMD3<Float>
    var rotation: simd_float3x3
    var fov90Span: Float
    var fov90SpanReciprocal: Float
    var jitter: SIMD2<Float>
    var frameSeed: UInt32
    
    // TODO: Allow 'sampleCount' to dynamically scale, matching a target FPS.
    // Aim to make the compute command last 4-6 ms, but allow manual overrides.
    // Only sample every few frames, so that most commands can occur in a single
    // command buffer. The range should be capped between 3 and 16 by default.
    // However, you can extend the range as part of the overriding ability.
    //
    // TODO: Does the AGX dynamic frequency scaling make this not viable?
    var lightPower: Float16
    var sampleCount: UInt16
    var maxRayHitTime: Float
    var exponentialFalloffDecayConstant: Float
    var minimumAmbientIllumination: Float
    var diffuseReflectanceScale: Float
  }
  var previousArguments: Arguments?
  
  // Objects to encapsulate complex operations.
  var accelBuilder: AccelerationStructureBuilder!
  var upscaler: Upscaler!
  
  enum RenderingMode: Equatable {
    // Generated procedurally or read from a file.
    case `static`
    
    // Visualize an MD simulation running in real-time.
    case molecularSimulation
  }
  static let renderingMode: RenderingMode = .static
  
  // Variables for loading static geometry.
  var staticProvider: (any MRStaticAtomProvider)!
  static func createStaticProvider() -> any MRStaticAtomProvider {
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
    
    // Initialize resolution and aspect ratio for rendering.
    let constants = MTLFunctionConstantValues()
    
    // Actual texture width.
    var screenWidth: UInt32 = .init(ContentView.size / 2)
    constants.setConstantValue(&screenWidth, type: .uint, index: 0)
    
    // Actual texture height.
    var screenHeight: UInt32 = .init(ContentView.size / 2)
    constants.setConstantValue(&screenHeight, type: .uint, index: 1)
    
    var suppressSpecular: Bool = false
    constants.setConstantValue(&suppressSpecular, type: .bool, index: 2)
    
    // Initialize the compute pipeline.
    let url = Bundle.main.url(
      forResource: "MolecularRendererGPU", withExtension: "metallib")!
    let library = try! device.makeLibrary(URL: url)
    
    let function = try! library.makeFunction(
      name: "renderMain", constantValues: constants)
    let desc = MTLComputePipelineDescriptor()
    desc.computeFunction = function
    desc.maxCallStackDepth = 5
    self.rayTracingPipeline = try! device
      .makeComputePipelineState(descriptor: desc, options: [], reflection: nil)
    
    let atomRadii = GlobalStyleProvider.global.atomRadii
    let atomColors = GlobalStyleProvider.global.atomColors
    
    // Initialize the atom statistics.
    let atomStatisticsSize = MemoryLayout<MRAtomStyle>.stride
    let stylesBufferSize = atomRadii.count * atomStatisticsSize
    precondition(MemoryLayout<MRAtom>.stride == 16, "Unexpected atom size.")
    precondition(atomStatisticsSize == 8, "Unexpected atom statistics size.")
    precondition(
      atomRadii.count == atomColors.count,
      "Atom statistics arrays have different sizes.")
    self.styles = device.makeBuffer(length: stylesBufferSize)!
    
    // Write to the atom data buffer.
    do {
      let stylesPointer = styles.contents()
        .assumingMemoryBound(to: MRAtomStyle.self)
      for (index, (radius, color)) in zip(atomRadii, atomColors).enumerated() {
        stylesPointer[index] = MRAtomStyle(color: color, radius: radius)
      }
    }
    
    // Create delegate objects.
    self.accelBuilder = AccelerationStructureBuilder(renderer: self)
    self.upscaler = Upscaler(renderer: self)
    
    switch Self.renderingMode {
    case .static:
      self.staticProvider = Renderer.createStaticProvider()
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
    
    // Update MetalFX upscaler.
    self.upscaler.updateResources()
    
    // Command buffer shared between the geometry and rendering passes.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    
    var accel: MTLAccelerationStructure?
    if true {
      // The accelBuilder automatically caches acceleration structures, but
      // explicitly marking them as static allows it to compress the structures.
      var shouldCompact: Bool
      
      let atoms: [MRAtom]
      switch Self.renderingMode {
      case .static:
        atoms = staticProvider.atoms
        shouldCompact = true
      case .molecularSimulation:
        atoms = self.simulator.getAtoms()
        shouldCompact = false
      }
      accel = accelBuilder.build(
        atoms: atoms,
        commandBuffer: commandBuffer,
        shouldCompact: shouldCompact)
    }
    
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(rayTracingPipeline)
    encodeArguments(encoder: encoder)
    encoder.setBuffer(styles, offset: 0, index: 1)
    encoder.setAccelerationStructure(accel!, bufferIndex: 2)
    
    // Acquire reference to the drawable.
    let drawable = view.metalLayer.nextDrawable()!
    precondition(drawable.texture.width == Int(ContentView.size))
    precondition(drawable.texture.height == Int(ContentView.size))
    let textures = upscaler.currentTextures
    encoder.setTextures(
      [textures.color, textures.depth, textures.motion], range: 0..<3)
    
    // Dispatch an even number of threads (the shader will rearrange them).
    let viewSize = Int(ContentView.size / 2)
    let numThreadgroupsX = (viewSize + 15) / 16
    let numThreadgroupsY = (viewSize + 15) / 16
    encoder.dispatchThreadgroups(
      MTLSizeMake(numThreadgroupsX, numThreadgroupsY, 1),
      threadsPerThreadgroup: MTLSizeMake(16, 16, 1))
    encoder.endEncoding()
    upscaler.upscale(
      commandBuffer: commandBuffer, drawableTexture: drawable.texture)
    
    // Present drawable and signal the semaphore.
    commandBuffer.present(drawable)
    commandBuffer.addCompletedHandler { [self] _ in
      renderSemaphore.signal()
    }
    commandBuffer.commit()
  }
  
  func encodeArguments(encoder: MTLComputeCommandEncoder) {
    withUnsafeTemporaryAllocation(
      of: Arguments.self, capacity: 2
    ) { bufferPointer in
      if Renderer.debuggingJitter {
        // Log the jitter to the console.
        print(upscaler.jitterOffsets)
        
        // Make the jitter clearly visible in the image.
        upscaler.jitterOffsets *= 50
      }
      
      let fov90Span = 0.5 * Double(ContentView.size / 2)
      let fov90SpanReciprocal = simd_precise_recip(fov90Span)
      let (azimuth, zenith) = eventTracker.playerState.rotations
      
      let maxRayHitTime: Float = 1.0 // range(0...100, 0.2)
      let minimumAmbientIllumination: Float = 0.07 // range(0...1, 0.01)
      let diffuseReflectanceScale: Float = 0.5 // range(0...1, 0.1)
      let decayConstant: Float = 2.0 // range(0...20, 0.25)
      
      let args = Arguments(
        position: self.eventTracker.playerState.position,
        rotation: azimuth * zenith,
        fov90Span: Float(fov90Span),
        fov90SpanReciprocal: Float(fov90SpanReciprocal),
        jitter: upscaler.jitterOffsets,
        frameSeed: UInt32.random(in: 0...UInt32.max),
        
        lightPower: GlobalStyleProvider.global.lightPower,
        sampleCount: 3,
        maxRayHitTime: maxRayHitTime,
        exponentialFalloffDecayConstant: decayConstant,
        minimumAmbientIllumination: minimumAmbientIllumination,
        diffuseReflectanceScale: diffuseReflectanceScale)
      
      bufferPointer[0] = args
      if let previousArguments = self.previousArguments {
        bufferPointer[1] = previousArguments
      } else {
        bufferPointer[1] = args
      }
      self.previousArguments = args
      
      let argsLength = 2 * MemoryLayout<Arguments>.stride
      let baseAddress = bufferPointer.baseAddress!
      encoder.setBytes(baseAddress, length: argsLength, index: 0)
    }
  }
}
