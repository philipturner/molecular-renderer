//
//  MRRenderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/17/23.
//

import Metal
import MetalFX
import class QuartzCore.CAMetalLayer

public class MRRenderer {
  var offline: Bool
  var upscaleFactor: Int?
  var intermediateSize: SIMD2<Int>
  var jitterFrameID: Int = 0
  var jitterOffsets: SIMD2<Float> = .zero
  var textureIndex: Int = 0
  
  // The time of this frame.
  var time: MRTimeContext!
  var renderIndex: Int = 0
  var resetTracker: ResetTracker = .init()
  
  // Objects that supply data to the renderer.
  var atomProvider: MRAtomProvider!
  var atomStyleProvider: MRAtomStyleProvider!
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var accelBuilder: MRAccelBuilder!
  var upscaler: MTLFXTemporalScaler?
  var rayTracingPipeline: MTLComputePipelineState!
  var encodePipeline: MTLComputePipelineState!
  var decodePipeline: MTLComputePipelineState!
  
  var offlineEncodingQueue: DispatchQueue?
  var lastCommandBuffer: MTLCommandBuffer?
  var lastHandledCommandBuffer: MTLCommandBuffer?
  
  struct IntermediateTextures {
    var color: MTLTexture
    var depth: MTLTexture?
    var motion: MTLTexture?
    
    // Metal is forcing me to make another texture for this, because the
    // drawable texture "must have private storage mode".
    var upscaled: MTLTexture?
    
    // Buffer backing the texture for offline rendering.
    var backingBuffer: MTLBuffer?
  }
  
  // Double-buffer the textures to remove dependencies between frames.
  var textures: [IntermediateTextures] = []
  private static func makeFramesInFlight(offline: Bool) -> Int {
    offline ? 4 : 2
  }
  var framesInFlight: Int { Self.makeFramesInFlight(offline: offline) }
  var currentTextures: IntermediateTextures {
    self.textures[jitterFrameID % framesInFlight]
  }
  
  // Cache previous arguments to generate motion vectors.
  var previousArguments: Arguments?
  var currentArguments: Arguments?
  var lights: [MRLight] = []
  var lightsBuffer: MTLBuffer
  
  // Enter the width and height of the texture to present, not the resolution
  // you expect the internal GPU shader to write to.
  public init(descriptor: MRRendererDescriptor) {
    // Initialize Metal resources.
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!
    descriptor.assertValid()
    
    self.offline = descriptor.offline
    if offline {
      self.upscaleFactor = nil
      self.intermediateSize = 2 &* SIMD2(descriptor.width!, descriptor.height!)
      self.offlineEncodingQueue = DispatchQueue(
        label: "com.philipturner.molecular-renderer.MRRenderer.offlineEncodingQueue")
    } else {
      self.upscaleFactor = descriptor.upscaleFactor
      self.intermediateSize = SIMD2(
        descriptor.width! / upscaleFactor!,
        descriptor.height! / upscaleFactor!)
      guard descriptor.width! % upscaleFactor! == 0,
            descriptor.height! % upscaleFactor! == 0 else {
        fatalError(
          "'MRRenderer' only accepts image sizes divisible by the upscale factor.")
      }
    }
    
    // Ensure the textures use lossless compression.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeBlitCommandEncoder()!
    
    for _ in 0..<Self.makeFramesInFlight(offline: offline) {
      let desc = MTLTextureDescriptor()
      desc.storageMode = .private
      desc.usage = [ .shaderWrite, .shaderRead ]
      
      if !offline {
        desc.width = intermediateSize.x
        desc.height = intermediateSize.y
        desc.pixelFormat = .rgb10a2Unorm
        let color = device.makeTexture(descriptor: desc)!
        color.label = "Intermediate Color"
        
        desc.pixelFormat = .r32Float
        let depth = device.makeTexture(descriptor: desc)!
        depth.label = "Intermediate Depth"
        
        desc.pixelFormat = .rg16Float
        let motion = device.makeTexture(descriptor: desc)!
        motion.label = "Intermediate Motion"
        
        desc.pixelFormat = .rgb10a2Unorm
        desc.width = intermediateSize.x * upscaleFactor!
        desc.height = intermediateSize.y * upscaleFactor!
        let upscaled = device.makeTexture(descriptor: desc)!
        upscaled.label = "Upscaled Color"
        
        textures.append(IntermediateTextures(
          color: color, depth: depth, motion: motion, upscaled: upscaled))
        
        for texture in [color, depth, motion, upscaled] {
          encoder.optimizeContentsForGPUAccess(texture: texture)
        }
      } else {
        desc.width = intermediateSize.x / 2
        desc.height = intermediateSize.y / 2
        desc.pixelFormat = .bgra8Unorm
        
        let backingBuffer = device.makeBuffer(
          length: 4 * descriptor.width! * descriptor.height!)!
        let color = backingBuffer.makeTexture(
          descriptor: desc, offset: 0, bytesPerRow: 4 * descriptor.width!)!
        
        textures.append(IntermediateTextures(
          color: color, backingBuffer: backingBuffer))
      }
    }
    encoder.endEncoding()
    commandBuffer.commit()
    
    let lightsBufferLength = 3 * 8 * MemoryLayout<MRLight>.stride
    precondition(MemoryLayout<MRLight>.stride == 16)
    self.lightsBuffer = device.makeBuffer(length: lightsBufferLength)!
    
    let library = try! device.makeLibrary(URL: descriptor.url!)
    self.accelBuilder = MRAccelBuilder(renderer: self, library: library)
    accelBuilder.reportPerformance = descriptor.reportPerformance
    accelBuilder.sceneSize = descriptor.sceneSize
    
    if !offline {
      initUpscaler()
    }
    initRayTracer(library: library)
    initSerializer(library: library)
  }
  
  func initUpscaler() {
    guard let upscaleFactor else {
      fatalError("Upscaler requires an upscale factor.")
    }
    
    let desc = MTLFXTemporalScalerDescriptor()
    desc.inputWidth = intermediateSize.x
    desc.inputHeight = intermediateSize.y
    desc.outputWidth = intermediateSize.x * upscaleFactor
    desc.outputHeight = intermediateSize.y * upscaleFactor
    desc.colorTextureFormat = textures[0].color.pixelFormat
    desc.depthTextureFormat = textures[0].depth!.pixelFormat
    desc.motionTextureFormat = textures[0].motion!.pixelFormat
    desc.outputTextureFormat = desc.colorTextureFormat
    
    desc.isAutoExposureEnabled = false
    desc.isInputContentPropertiesEnabled = false
    desc.inputContentMinScale = Float(upscaleFactor)
    desc.inputContentMaxScale = Float(upscaleFactor)
    
    guard let upscaler = desc.makeTemporalScaler(device: device) else {
      fatalError("The temporal scaler effect is not usable!")
    }
    
    self.upscaler = upscaler
    
    // We already store motion vectors in units of pixels. The default value
    // multiplies the vector by 'intermediateSize', which we don't want.
    upscaler.motionVectorScaleX = 1
    upscaler.motionVectorScaleY = 1
    upscaler.isDepthReversed = true
  }
  
  func initRayTracer(library: MTLLibrary) {
    // Initialize resolution and aspect ratio for rendering.
    let constants = MTLFunctionConstantValues()
    
    // Actual texture width.
    var screenWidth: UInt32 = .init(intermediateSize.x)
    constants.setConstantValue(&screenWidth, type: .uint, index: 0)
    
    // Actual texture height.
    var screenHeight: UInt32 = .init(intermediateSize.y)
    constants.setConstantValue(&screenHeight, type: .uint, index: 1)
    
    var offline: Bool = offline
    constants.setConstantValue(&offline, type: .bool, index: 2)
    
    var voxel_width_numer: Float = 4
    constants.setConstantValue(&voxel_width_numer, type: .float, index: 10)
    
    guard let sceneSize = accelBuilder.sceneSize else {
      fatalError("Voxel size denominator not set.")
    }
    var voxel_width_denom: Float = (sceneSize == .small) ? 16 : 8
    constants.setConstantValue(&voxel_width_denom, type: .float, index: 11)
    
    // Initialize the compute pipeline.
    let function = try! library.makeFunction(
      name: "renderAtoms", constantValues: constants)
    
    let desc = MTLComputePipelineDescriptor()
    desc.computeFunction = function
    desc.maxTotalThreadsPerThreadgroup = 1024
    self.rayTracingPipeline = try! device.makeComputePipelineState(
      descriptor: desc, options: [], reflection: nil)
  }
  
  func initSerializer(library: MTLLibrary) {
    let constants = MTLFunctionConstantValues()
    let configs: [
      (Bool, ReferenceWritableKeyPath<MRRenderer, MTLComputePipelineState?>)
    ] = [(true, \.encodePipeline), (false, \.decodePipeline)]
    
    for (encode, keyPath) in configs {
      var encodeCopy = encode
      constants.setConstantValue(&encodeCopy, type: .bool, index: 300)
      
      let function = try! library.makeFunction(
        name: "process_atoms", constantValues: constants)
      let pipeline = try! device.makeComputePipelineState(function: function)
      self[keyPath: keyPath] = pipeline
    }
  }
}

extension MRRenderer {
  // Perform any updating work that happens before encoding the rendering work.
  // This should be called as early as possible each frame, to hide any latency
  // between now and when it can encode the rendering work.
  private func updateResources() {
    self.updateGeometry(time)
    self.accelBuilder.updateResources()
    
    self.jitterFrameID += 1
    if offline {
      self.jitterOffsets = SIMD2(repeating: 0)
    } else {
      self.jitterOffsets = makeJitterOffsets()
    }
    self.textureIndex = (self.textureIndex + 1) % 2
    self.renderIndex = (self.renderIndex + 1) % 3
  }
  
  private func makeJitterOffsets() -> SIMD2<Float> {
    func halton(index: UInt32, base: UInt32) -> Float {
      var result: Float = 0.0
      var fractional: Float = 1.0
      var currentIndex: UInt32 = index
      while currentIndex > 0 {
        fractional /= Float(base)
        result += fractional * Float(currentIndex % base)
        currentIndex /= base
      }
      return result
    }
    
    // The sample uses a Halton sequence rather than purely random numbers to
    // generate the sample positions to ensure good pixel coverage. This has the
    // result of sampling a different point within each pixel every frame.
    let jitterIndex = UInt32(self.jitterFrameID % 32 + 1)
    
    // Return Halton samples (+/- 0.5, +/- 0.5) that represent offsets of up to
    // half a pixel.
    let x = halton(index: jitterIndex, base: 2) - 0.5
    let y = halton(index: jitterIndex, base: 3) - 0.5
    
    // We're not sampling textures or working with multiple coordinate spaces.
    // No need to flip the Y coordinate to match another coordinate space.
    return SIMD2(x, y)
  }
  
  private func upscale(
    commandBuffer: MTLCommandBuffer,
    drawableTexture: MTLTexture
  ) {
    guard let upscaler else {
      fatalError("Attempted to upscale in offline mode.")
    }
    resetTracker.update(time: time)
    
    // Bind the intermediate textures.
    let currentTextures = self.currentTextures
    upscaler.reset = resetTracker.resetUpscaler
    upscaler.colorTexture = currentTextures.color
    upscaler.depthTexture = currentTextures.depth
    upscaler.motionTexture = currentTextures.motion
    upscaler.outputTexture = currentTextures.upscaled
    upscaler.jitterOffsetX = -self.jitterOffsets.x
    upscaler.jitterOffsetY = -self.jitterOffsets.y
    upscaler.encode(commandBuffer: commandBuffer)
    
    // Metal is forcing me to copy the upscaled texture to the drawable.
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    blitEncoder.copy(from: currentTextures.upscaled!, to: drawableTexture)
    blitEncoder.endEncoding()
  }
}

extension MRRenderer {
  public func render(
    layer: CAMetalLayer,
    handler: @escaping () -> Void
  ) {
    guard !offline else {
      fatalError(
        "Tried to render to a CAMetalLayer, but configured for offline rendering.")
    }
    defer {
      // Invalidate the time.
      self.time = nil
    }
    
    var commandBuffer = self.render()
    commandBuffer.commit()
    commandBuffer = commandQueue.makeCommandBuffer()!
    
    // Acquire a reference to the drawable.
    let drawable = layer.nextDrawable()!
    let upscaledSize = intermediateSize &* upscaleFactor!
    precondition(drawable.texture.width == upscaledSize.x)
    precondition(drawable.texture.height == upscaledSize.y)
    
    // Encode the upscaling pass.
    upscale(commandBuffer: commandBuffer, drawableTexture: drawable.texture)
    
    // Present the drawable and signal the semaphore.
    commandBuffer.present(drawable)
    commandBuffer.addCompletedHandler { _ in
      handler()
    }
    commandBuffer.commit()
  }
  
  public func render(
    handler: @escaping (UnsafePointer<UInt8>) -> Void
  ) {
    guard offline else {
      fatalError(
        "Tried to render to a pixel buffer, but configured for real-time rendering.")
    }
    defer {
      // Invalidate the time.
      self.time = nil
    }
    
    let commandBuffer = render()
    let textures = self.currentTextures
    commandBuffer.addCompletedHandler { commandBuffer in
      let backingBuffer = textures.backingBuffer!
      let pixels = backingBuffer.contents().assumingMemoryBound(to: UInt8.self)
      self.offlineEncodingQueue!.async {
        handler(pixels)
        self.lastHandledCommandBuffer = commandBuffer
      }
    }
    commandBuffer.commit()
    lastCommandBuffer = commandBuffer
  }
  
  // Call this before accessing the contents of the offline-rendered buffer.
  public func stopRendering() {
    guard offline else {
      fatalError(
        "Tried to stop rendering, but configured for real-time rendering.")
    }
    
    lastCommandBuffer!.waitUntilCompleted()
    while lastHandledCommandBuffer !== lastCommandBuffer {
      usleep(50)
    }
    lastHandledCommandBuffer!.waitUntilCompleted()
    
    let semaphore = DispatchSemaphore(value: 0)
    self.offlineEncodingQueue!.sync {
      _ = semaphore.signal()
    }
    semaphore.wait()
  }
  
  private func render() -> MTLCommandBuffer {
    // TODO: Refactor, splitting into some separate files:
    // - MRRenderer + MRRendererDescriptor -> MRRenderer
    // - MRRenderer+Update
    // - MRRenderer+Render
    self.updateResources()
    
    var commandBuffer = commandQueue.makeCommandBuffer()!
    
    var encoder = commandBuffer.makeComputeCommandEncoder()!
    accelBuilder.buildDenseGrid(encoder: encoder)
    encoder.endEncoding()
    
    let frameID = accelBuilder.frameReportCounter
    func addHandler(
      _ closure: @escaping (inout MRFrameReport, Double) -> Void
    ) {
      commandBuffer.addCompletedHandler { [self] commandBuffer in
        let executionTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        self.accelBuilder.frameReportQueue.sync {
          for index in self.accelBuilder.frameReports.indices.reversed() {
            guard self.accelBuilder.frameReports[index].frameID == frameID else {
              continue
            }
            closure(&self.accelBuilder.frameReports[index], executionTime)
            break
          }
        }
      }
    }
    
    addHandler { $0.geometryTime = $1 }
    commandBuffer.commit()
    commandBuffer = commandQueue.makeCommandBuffer()!
    
    encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(rayTracingPipeline)
    accelBuilder.encodeGridArguments(encoder: encoder)
    accelBuilder.setGridWidth(arguments: &currentArguments!)
    
    // Encode the arguments.
    let tempAllocation = malloc(256)!
    if previousArguments == nil {
      previousArguments = currentArguments
    }
    let stride = MemoryLayout<Arguments>.stride
    precondition(stride <= 128)
    memcpy(tempAllocation, &currentArguments!, stride)
    memcpy(tempAllocation + 128, &previousArguments!, stride)
    encoder.setBytes(tempAllocation, length: 256, index: 0)
    free(tempAllocation)
    
    accelBuilder.styles.withUnsafeBufferPointer {
      let length = $0.count * MemoryLayout<MRAtomStyle>.stride
      encoder.setBytes($0.baseAddress!, length: length, index: 1)
    }
    
    // Encode the lights.
    let lightsBufferOffset = renderIndex * (lightsBuffer.length / 3)
    let lightsRawPointer = lightsBuffer.contents() + lightsBufferOffset
    let lightsPointer = lightsRawPointer.assumingMemoryBound(to: MRLight.self)
    for i in 0..<lights.count {
      lightsPointer[i] = lights[i]
    }
    encoder.setBuffer(lightsBuffer, offset: lightsBufferOffset, index: 2)
    
    // Encode the output textures.
    let textures = self.currentTextures
    if offline {
      encoder.setTexture(textures.color, index: 0)
    } else {
      encoder.setTextures(
        [textures.color, textures.depth!, textures.motion!], range: 0..<3)
    }
    
    // Dispatch an even number of threads (the shader will rearrange them).
    let numThreadgroupsX = (intermediateSize.x + 7) / 8
    let numThreadgroupsY = (intermediateSize.y + 7) / 8
    encoder.dispatchThreadgroups(
      MTLSizeMake(numThreadgroupsX, numThreadgroupsY, 1),
      threadsPerThreadgroup: MTLSizeMake(8, 8, 1))
    encoder.endEncoding()
    
    addHandler { $0.renderTime = $1 }
    return commandBuffer
  }
}
