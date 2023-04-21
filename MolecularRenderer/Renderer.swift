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
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var rayTracingPipeline: MTLComputePipelineState
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  
  // Memory objects for rendering.
  var atomData: MTLBuffer
  var atomBuffer: MTLBuffer
  var boundingBoxBuffer: MTLBuffer
  var accelerationStructure: MTLAccelerationStructure
  
  // Data for MetalFX upscaling.
  struct Arguments {
    var fov90Span: Float
    var fov90SpanReciprocal: Float
    var position: SIMD3<Float>
    var rotation: simd_float3x3
  }
  var previousArguments: Arguments?
  
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
    
    // Initialize the compute pipeline.
    let library = device.makeDefaultLibrary()!
    let name = Self.checkingFrameRate ? "checkFrameRate" : "renderMain"
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
    
    do {
      let atomDataPointer = atomData.contents()
        .assumingMemoryBound(to: AtomStatistics.self)
      for (index, (radius, color)) in zip(atomRadii, atomColors).enumerated() {
        atomDataPointer[index] = AtomStatistics(color: color, radius: radius)
      }
    }
    
    // Create the acceleration structure.
    
    let atoms: [Atom] = ExampleMolecules.taggedEthylene
    
    let atomSize = MemoryLayout<Atom>.stride
    let atomBufferSize = atoms.count * atomSize
    precondition(atomSize == 16, "Unexpected atom size.")
    self.atomBuffer = device.makeBuffer(length: atomBufferSize)!
    
    do {
      let atomsPointer = atomBuffer.contents()
        .assumingMemoryBound(to: Atom.self)
      for (index, atom) in atoms.enumerated() {
        atomsPointer[index] = atom
      }
    }
    
    let boundingBoxSize = MemoryLayout<BoundingBox>.stride
    let boundingBoxBufferSize = atoms.count * boundingBoxSize
    precondition(boundingBoxSize == 24, "Unexpected bounding box size.")
    self.boundingBoxBuffer = device.makeBuffer(length: boundingBoxBufferSize)!
    
    do {
      let boundingBoxesPointer = boundingBoxBuffer.contents()
        .assumingMemoryBound(to: BoundingBox.self)
      for (index, atom) in atoms.enumerated() {
        let boundingBox = atom.boundingBox
        boundingBoxesPointer[index] = boundingBox
      }
    }
    
    let geometryDesc = MTLAccelerationStructureBoundingBoxGeometryDescriptor()
    geometryDesc.primitiveDataBuffer = atomBuffer
    geometryDesc.primitiveDataStride = atomSize
    geometryDesc.primitiveDataBufferOffset = 0
    geometryDesc.primitiveDataElementSize = atomSize
    geometryDesc.boundingBoxCount = atoms.count
    geometryDesc.boundingBoxStride = boundingBoxSize
    geometryDesc.boundingBoxBufferOffset = 0
    geometryDesc.boundingBoxBuffer = boundingBoxBuffer
    
    let accelDesc = MTLPrimitiveAccelerationStructureDescriptor()
    accelDesc.geometryDescriptors = [geometryDesc]
    do {
      // Copied from Apple's ray tracing sample code:
      // https://developer.apple.com/documentation/metal/metal_sample_code_library/control_the_ray_tracing_process_using_intersection_queries
      
      // Query for the sizes needed to store and build the acceleration
      // structure.
      let accelSizes = device.accelerationStructureSizes(descriptor: accelDesc)
      
      // Allocate an acceleration structure large enough for this descriptor.
      // This method doesn't actually build the acceleration structure, but
      // rather allocates memory.
      let structure = device.makeAccelerationStructure(
        size: accelSizes.accelerationStructureSize)!
      
      // Allocate scratch space Metal uses to build the acceleration structure.
      let scratchBuffer = device.makeBuffer(
        length: 32 + accelSizes.buildScratchBufferSize)!
      
      // Create a command buffer that performs the acceleration structure build.
      var commandBuffer = commandQueue.makeCommandBuffer()!
      
      // Create an acceleration structure command encoder.
      var encoder = commandBuffer.makeAccelerationStructureCommandEncoder()!
      
      // Schedule the actual acceleration structure build.
      encoder.build(
        accelerationStructure: structure, descriptor: accelDesc,
        scratchBuffer: scratchBuffer, scratchBufferOffset: 32)
      
      // Compute and write the compacted acceleration structure size into the
      // buffer.
      encoder.writeCompactedSize(
        accelerationStructure: structure, buffer: scratchBuffer, offset: 0,
        sizeDataType: .uint)
      
      // End encoding, and commit the command buffer so the GPU can start
      // building the acceleration structure.
      encoder.endEncoding()
      
      commandBuffer.commit()
      commandBuffer.waitUntilCompleted()
      
      let compactedSize = scratchBuffer.contents()
        .assumingMemoryBound(to: UInt32.self).pointee
      let compactedStructure = device
        .makeAccelerationStructure(size: Int(compactedSize))!
      
      commandBuffer = commandQueue.makeCommandBuffer()!
      encoder = commandBuffer.makeAccelerationStructureCommandEncoder()!
      
      // Encode the command to copy and compact the acceleration structure into
      // the smaller acceleration structure.
      encoder.copyAndCompact(
        sourceAccelerationStructure: structure,
        destinationAccelerationStructure: compactedStructure)
      
      encoder.endEncoding()
      commandBuffer.commit()
      
      self.accelerationStructure = compactedStructure
    }
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
      if Self.debuggingFrameRate {
        print("Correcting misalignment by / 2")
      }
      nextFrameID += (targetFrameID - nextFrameID) / 2
    } else if abs(targetFrameID - nextFrameID) == step {
      // Wait a while to smooth out noise.
      if sustainedMisalignmentDuration >= 10 ||
         sustainedAlignmentDuration >= 10 {
        if Self.debuggingFrameRate {
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
    
    if Self.debuggingFrameRate {
      print(
        nextFrameID - previousFrameID, targetFrameID - nextFrameID,
        sustainedMisalignment, sustainedMisalignmentDuration,
        sustainedAlignmentDuration, currentRefreshRate.load(ordering: .relaxed))
    }
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(rayTracingPipeline)
    
    if Self.checkingFrameRate {
      // Set the time to determine synchronization.
      var time1 = Float(adjustedFrameID) / Float(120)
      var time2 = Float(
        seconds(start: startTimeStamp!, end: previousTimeStamp!))
      encoder.setBytes(&time1, length: 4, index: 0)
      encoder.setBytes(&time2, length: 4, index: 1)
    } else {
      withUnsafeTemporaryAllocation(
        of: Arguments.self, capacity: 2
      ) { bufferPointer in
        let fov90Span = Double(ContentView.size / 2)
        let fov90SpanReciprocal = simd_precise_recip(fov90Span)
        let (azimuth, zenith) = eventTracker.playerState.rotations
        let args = Arguments(
          fov90Span: Float(fov90Span),
          fov90SpanReciprocal: Float(fov90SpanReciprocal),
          position: self.eventTracker.playerState.position,
          rotation: azimuth * zenith)
        
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
      
      encoder.setBuffer(atomData, offset: 0, index: 1)
      encoder.setAccelerationStructure(accelerationStructure, bufferIndex: 2)
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
}
