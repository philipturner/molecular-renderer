//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import Metal
import AppKit
import Atomics

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
  var view: CustomMetalView
  var layer: CAMetalLayer
  var startTimeStamp: CVTimeStamp?
  var previousTimeStamp: CVTimeStamp?
  
  // Data for robustly synchronizing with the refresh rate.
  var currentRefreshRate: ManagedAtomic<Int> = .init(0)
  var frameID: Int = 0
  var adjustedFrameID: Int = -1
  var sustainedMisalignment: Int = 0
  var sustainedMisalignmentDuration: Int = 0
  var sustainedAlignmentDuration: Int = 0
  static let checkingFrameRate = false
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var rayTracingPipeline: MTLComputePipelineState
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  
  // Memory objects for rendering.
  var accelerationStructure: MTLAccelerationStructure
  var boundingBoxBuffer: MTLBuffer
  
  init(view: CustomMetalView) {
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
    var screenWidth: UInt32 = 1024
    constants.setConstantValue(&screenWidth, type: .uint, index: 0)
    
    // Actual texture height.
    var screenHeight: UInt32 = 1024
    constants.setConstantValue(&screenHeight, type: .uint, index: 1)
    
    // How many pixels are covered in either direction @ FOV=90?
    let fov90Span: UInt32 = 1024 / 2
    var fov90SpanReciprocal = 1 / Float(fov90Span)
    constants.setConstantValue(&fov90SpanReciprocal, type: .float, index: 2)
    
    // Initialize the compute pipeline.
    let library = device.makeDefaultLibrary()!
    let name = Self.checkingFrameRate ? "checkFrameRate" : "renderMain"
    let function = try! library.makeFunction(
      name: name, constantValues: constants)
    self.rayTracingPipeline = try! device
      .makeComputePipelineState(function: function)
    
    // Hard-code all the geometry (for now).
    let spheres: [SpherePrototype] = [
      .init(origin: SIMD3(0, 0, -1), element: 6)
    ]
    
    // Create the acceleration structure.
    
    let boundingBoxSize = MemoryLayout<BoundingBox>.stride
    let boundingBoxBufferSize = spheres.count * boundingBoxSize
    precondition(boundingBoxSize == 24, "Unexpected bounding box size.")
    self.boundingBoxBuffer = device.makeBuffer(length: boundingBoxBufferSize)!
    
    let geometryDesc = MTLAccelerationStructureBoundingBoxGeometryDescriptor()
    geometryDesc.boundingBoxCount = spheres.count
    geometryDesc.boundingBoxStride = boundingBoxSize
    geometryDesc.boundingBoxBufferOffset = 0
    geometryDesc.boundingBoxBuffer = boundingBoxBuffer
    
  }
}

extension NSScreen {
  var screenNumber: UInt32 {
    (self.deviceDescription[
      NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber).uint32Value
  }
}

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
  
  func update() {
    renderSemaphore.wait()
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
      print("Correcting misalignment by / 2")
      nextFrameID += (targetFrameID - nextFrameID) / 2
    } else if abs(targetFrameID - nextFrameID) == step {
      // Wait a while to smooth out noise.
      if sustainedMisalignmentDuration >= 10 ||
         sustainedAlignmentDuration >= 10 {
        print("Correcting misalignment by +/- 1")
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
    
    print(nextFrameID - previousFrameID, targetFrameID - nextFrameID, sustainedMisalignment, sustainedMisalignmentDuration, sustainedAlignmentDuration, currentRefreshRate.load(ordering: .relaxed))
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(rayTracingPipeline)
    
    // Set the time to determine synchronization.
    var time1 = Float(adjustedFrameID) / Float(120)
    var time2 = Float(seconds(start: startTimeStamp!, end: previousTimeStamp!))
    encoder.setBytes(&time1, length: 4, index: 0)
    encoder.setBytes(&time2, length: 4, index: 1)
    
    // Acquire reference to the drawable.
    let drawable = view.metalLayer.nextDrawable()!
    precondition(drawable.texture.width == 1024)
    precondition(drawable.texture.height == 1024)
    encoder.setTexture(drawable.texture, index: 0)
    
    // Dispatch even number of threads (the shader will rearrange them).
    let numThreadgroupsX = (1024 + 15) / 16
    let numThreadgroupsY = (1024 + 15) / 16
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
}
