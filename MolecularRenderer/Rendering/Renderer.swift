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
  var frameID: Int = 0
  var adjustedFrameID: Int = -1
  var sustainedMisalignment: Int = 0
  var sustainedMisalignmentDuration: Int = 0
  var sustainedAlignmentDuration: Int = 0
  static let checkingFrameRate = false
  static let debuggingFrameRate = false
  static let debuggingJitter = false
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var rayTracingPipeline: MTLComputePipelineState
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  
  // Memory objects for rendering.
  var atomData: MTLBuffer
  
  // Cache previous arguments to generate motion vectors.
  struct Arguments {
    var fov90Span: Float
    var fov90SpanReciprocal: Float
    var jitter: SIMD2<Float>
    var position: SIMD3<Float>
    var rotation: simd_float3x3
  }
  var previousArguments: Arguments?
  
  // Objects to encapsulate complex operations.
  var accelBuilder: AccelerationStructureBuilder!
  var upscaler: Upscaler!
  
  init(view: RendererView) {
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
    var screenWidth: UInt32 = .init(ContentView.size)
    constants.setConstantValue(&screenWidth, type: .uint, index: 0)
    
    // Actual texture height.
    var screenHeight: UInt32 = .init(ContentView.size)
    constants.setConstantValue(&screenHeight, type: .uint, index: 1)
    
    // Whether to do antialiasing/upscaling.
    var useMetalFX: Bool = Upscaler.doingUpscaling
    constants.setConstantValue(&useMetalFX, type: .bool, index: 2)
    
    // Initialize the compute pipeline.
    let library = device.makeDefaultLibrary()!
    let name = Renderer.checkingFrameRate ? "checkFrameRate" : "renderMain"
    let function = try! library.makeFunction(
      name: name, constantValues: constants)
    self.rayTracingPipeline = try! device
      .makeComputePipelineState(function: function)
    
    // Initialize the atom statistics.
    let atomStatisticsSize = MemoryLayout<AtomStatistics>.stride
    let atomDataBufferSize = atomRadii.count * atomStatisticsSize
    precondition(atomStatisticsSize == 8, "Unexpected atom statistics size.")
    precondition(
      atomRadii.count == atomColors.count,
      "Atom statistics arrays have different sizes.")
    self.atomData = device.makeBuffer(length: atomDataBufferSize)!
    
    // Write to the atom data buffer.
    do {
      let atomDataPointer = atomData.contents()
        .assumingMemoryBound(to: AtomStatistics.self)
      for (index, (radius, color)) in zip(atomRadii, atomColors).enumerated() {
        atomDataPointer[index] = AtomStatistics(color: color, radius: radius)
      }
    }
    
    // Create delegate objects.
    self.accelBuilder = AccelerationStructureBuilder(renderer: self)
    self.upscaler = Upscaler(renderer: self)
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
        print("Frame stutter @ \(Date()): \(String(format: "%.2f", deltaFrames))")
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
    let ticksPerFrame = ticksPerSecond / 120
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
    120 / currentRefreshRate.load(ordering: .relaxed)
  }
  
  func updateFrameID() {
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
  }
}

// Code for sending commands to the GPU.
extension Renderer {
  func update() {
    self.renderSemaphore.wait()
    self.updateFrameID()
    
    var accel: MTLAccelerationStructure?
    if Renderer.checkingFrameRate == false {
      let atoms: [Atom] = ExampleMolecules.taggedEthylene
      accel = self.accelBuilder.build(atoms: atoms)
    }
    self.upscaler.updateResources()
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(rayTracingPipeline)
    
    if Renderer.checkingFrameRate {
      // Set the time to determine synchronization.
      var time1 = Float(adjustedFrameID) / Float(120)
      var time2 = Float(
        seconds(start: startTimeStamp!, end: previousTimeStamp!))
      encoder.setBytes(&time1, length: 4, index: 0)
      encoder.setBytes(&time2, length: 4, index: 1)
    } else {
      encodeArguments(encoder: encoder)
      encoder.setBuffer(atomData, offset: 0, index: 1)
      encoder.setAccelerationStructure(accel!, bufferIndex: 2)
    }
    
    // Acquire reference to the drawable.
    let drawable = view.metalLayer.nextDrawable()!
    precondition(drawable.texture.width == Int(ContentView.size))
    precondition(drawable.texture.height == Int(ContentView.size))
    encoder.setTexture(drawable.texture, index: 0)
    
    // Dispatch even number of threads (the shader will rearrange them).
    let numThreadgroupsX = (Int(ContentView.size) + 15) / 16
    let numThreadgroupsY = (Int(ContentView.size) + 15) / 16
    encoder.dispatchThreadgroups(
      MTLSizeMake(numThreadgroupsX, numThreadgroupsY, 1),
      threadsPerThreadgroup: MTLSizeMake(16, 16, 1))
    encoder.endEncoding()
    
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
      let fov90Span = Double(ContentView.size / 2)
      let fov90SpanReciprocal = simd_precise_recip(fov90Span)
      let (azimuth, zenith) = eventTracker.playerState.rotations
      var args = Arguments(
        fov90Span: Float(fov90Span),
        fov90SpanReciprocal: Float(fov90SpanReciprocal),
        jitter: upscaler.jitterOffsets,
        position: self.eventTracker.playerState.position,
        rotation: azimuth * zenith)
      if Renderer.debuggingJitter {
        // Log the jitter to the console.
        print(args.jitter)
        
        // Make the jitter clearly visible in the image.
        args.jitter *= 50
      }
      
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
