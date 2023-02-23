//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import MetalKit

// TODO: Establish 90-degree FOV until window resizing is allowed. Afterward,
// FOV in each direction changes to match the number of pixels. This might be
// able to be hard-coded into the shader.

class Renderer {
  var view: MTKView
  var startTimestamp: CFTimeInterval?
  var previousTimestamp: CFTimeInterval?
  
  var refreshRate: Int
  var frameID: Int = 0
  var previousScreen: NSScreen
  var displayLink: CVDisplayLink!
  
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var rayTracingPipeline: MTLComputePipelineState
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  
  init(view: MTKView) {
    self.view = view
    self.refreshRate =  NSScreen.main!.maximumFramesPerSecond
    
    // Set up the display link.
    CVDisplayLinkCreateWithActiveCGDisplays(&self.displayLink)
    self.previousScreen = NSScreen.main!
    CVDisplayLinkSetCurrentCGDisplay(displayLink, previousScreen.screenNumber)
    // (CVDisplayLink, UnsafePointer<CVTimeStamp>, UnsafePointer<CVTimeStamp>, CVOptionFlags, UnsafeMutablePointer<CVOptionFlags>) -> CVReturn
    CVDisplayLinkSetOutputHandler(displayLink) {
      // TODO: Resume progress here.
    }
    
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
  func update() {
    renderSemaphore.wait()
    
    // Check whether a frame was skipped.
    let currentTimestamp = CACurrentMediaTime()
    if let previousTimestamp = previousTimestamp {
      let deltaFrames = (currentTimestamp - previousTimestamp) * Double(refreshRate)
      if deltaFrames > 1.5 {
        print("Frame stutter @ \(Date()): \(String(format: "%.2f", deltaFrames))")
      }
    }
    previousTimestamp = currentTimestamp

    
    frameID += 1
    if startTimestamp == nil {
      self.startTimestamp = CACurrentMediaTime()
    }
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(rayTracingPipeline)
    
    // Set the time to determine synchronization.
    var time1 = Float(frameID) / Float(refreshRate)
    var time2 = Float(CACurrentMediaTime() - self.startTimestamp!)
    encoder.setBytes(&time1, length: 4, index: 0)
    encoder.setBytes(&time2, length: 4, index: 1)
    
    // Acquire reference to the drawable.
    let drawable = view.currentDrawable!
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
