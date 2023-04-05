//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import Metal
import AppKit
import Atomics

// TODO: Establish 90-degree FOV until window resizing is allowed. Afterward,
// FOV in each direction changes to match the number of pixels. This might be
// able to be hard-coded into the shader.

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
  var view: CustomMetalView
  var layer: CAMetalLayer
  var startTimeStamp: CVTimeStamp?
  var previousTimeStamp: CVTimeStamp?
  
  var currentRefreshRate: ManagedAtomic<Int> = .init(0)
  var frameID: Int = 0
  var adjustedFrameID: Int = -1
  
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var rayTracingPipeline: MTLComputePipelineState
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  
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
    var screenWidth: UInt32 = 1024
    var screenHeight: UInt32 = 1024
    var fov90Span: UInt32 = 1024
    constants.setConstantValue(&screenWidth, type: .uint, index: 0)
    constants.setConstantValue(&screenHeight, type: .uint, index: 1)
    constants.setConstantValue(&fov90Span, type: .uint, index: 2)
    
    // Initialize the compute pipeline.
    let library = device.makeDefaultLibrary()!
    let function = try! library.makeFunction(
      name: "renderScene", constantValues: constants)
    self.rayTracingPipeline = try! device
      .makeComputePipelineState(function: function)
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
    
    let deltaTicks = end.hostTime - start.hostTime
    return Double(deltaTicks) / Double(ticksPerFrame)
  }
  
  func seconds(start: CVTimeStamp, end: CVTimeStamp) -> Double {
    #if arch(arm64)
    let ticksPerSecond: Int = 24 * 1000 * 1000
    #else
    #error("This does not work on x86.")
    #endif
    
    let deltaTicks = end.hostTime - start.hostTime
    return Double(deltaTicks) / Double(ticksPerSecond)
  }
  
  // Time per frame in multiples of 120 Hz.
  func frameStep() -> Int {
    120 / currentRefreshRate.load(ordering: .relaxed)
  }
  
  func update() {
    renderSemaphore.wait()
    frameID += 1
    
    let previousAdjustedFrameID = adjustedFrameID
    
    // If there's a stutter, the actual frame ID will just much farther ahead.
    let actualAdjustedFrameID = Int(
      frames(start: startTimeStamp!, end: previousTimeStamp!))
    
    // We don't want to jump too far head, in case the previous one was actually
    // slightly overshooting (due to rounding error).
    let step = frameStep()
    if actualAdjustedFrameID - step > adjustedFrameID {
      print("Correcting stutter")
      if step == 1 {
        adjustedFrameID = actualAdjustedFrameID
      } else {
        adjustedFrameID = actualAdjustedFrameID - step
        
        // TODO: This still doesn't handle 60 Hz displays very well.
        print("First:", actualAdjustedFrameID - adjustedFrameID)
        while (adjustedFrameID - previousAdjustedFrameID) % step != 0 {
          //        print("Correction type 1")
          adjustedFrameID += 1
        }
        print("Second:", actualAdjustedFrameID - adjustedFrameID)
        if adjustedFrameID - step > actualAdjustedFrameID {
          print("Correction type 2")
          adjustedFrameID -= step
        }
        if adjustedFrameID < previousAdjustedFrameID + step {
          print("Correction type 3")
          adjustedFrameID = previousAdjustedFrameID + step
        }
      }
    } else {
      adjustedFrameID += step
    }
    
    if actualAdjustedFrameID < adjustedFrameID - 2 * step {
      // Something very bad just happened.
      print("Correction type 4")
      adjustedFrameID -= step
    } else {
      precondition(adjustedFrameID > previousAdjustedFrameID, "Frame IDs not monotonically increasing.")
      precondition(actualAdjustedFrameID - adjustedFrameID < 10, "Frame IDs not monotonically increasing.")
    }
    print(adjustedFrameID - previousAdjustedFrameID, actualAdjustedFrameID - adjustedFrameID, view.window!.screen!.maximumFramesPerSecond)
    
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
