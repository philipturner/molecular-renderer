//
//  MRRenderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 6/17/23.
//

import Metal
import MetalFX
import func QuartzCore.CACurrentMediaTime
import class QuartzCore.CAMetalLayer
import struct simd.simd_float3x3

// Partially sourced from:
// https://developer.apple.com/documentation/metalfx/applying_temporal_antialiasing_and_upscaling_using_metalfx

@_alignment(16)
internal struct Arguments {
  var fovMultiplier: Float
  var positionX: Float
  var positionY: Float
  var positionZ: Float
  var rotation: simd_float3x3
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
  
  var gridWidth: UInt16
  var useUniformGrid: UInt16 = 1
}

public class MRRenderer {
  var upscaledSize: SIMD2<Int>
  var intermediateSize: SIMD2<Int>
  var jitterFrameID: Int = 0
  var jitterOffsets: SIMD2<Float> = .zero
  var textureIndex: Int = 0
  var resetScaler = true
  
  // Main rendering resources.
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var accelBuilder: MRAccelBuilder!
  var rayTracingPipeline: MTLComputePipelineState!
  var upscaler: MTLFXTemporalScaler!
  
  struct IntermediateTextures {
    var color: MTLTexture
    var depth: MTLTexture
    var motion: MTLTexture
    
    // Metal is forcing me to make another texture for this, because the
    // drawable texture "must have private storage mode".
    var upscaled: MTLTexture
  }
  
  // Double-buffer the textures to remove dependencies between frames.
  var textures: [IntermediateTextures] = []
  var currentTextures: IntermediateTextures {
    self.textures[jitterFrameID % 2]
  }
  
  // Cache previous arguments to generate motion vectors.
  var previousArguments: Arguments?
  var currentArguments: Arguments?
  var shouldCompact: Bool = false
  
  // Enter the width and height of the texture to present, not the resolution
  // you expect the internal GPU shader to write to.
  public init(
    metallibURL: URL,
    width: Int,
    height: Int
  ) {
    // Initialize Metal resources.
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!
    
    guard width % 2 == 0, height % 2 == 0 else {
      fatalError("MRRenderer only accepts even image sizes.")
    }
    self.upscaledSize = SIMD2(width, height)
    self.intermediateSize = SIMD2(width / 2, height / 2)
    
    // Ensure the textures use lossless compression.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeBlitCommandEncoder()!
    
    for _ in 0..<2 {
      let desc = MTLTextureDescriptor()
      desc.width = intermediateSize.x
      desc.height = intermediateSize.y
      desc.storageMode = .private
      desc.usage = [ .shaderWrite, .shaderRead ]
      
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
      desc.width = upscaledSize.x
      desc.height = upscaledSize.y
      let upscaled = device.makeTexture(descriptor: desc)!
      upscaled.label = "Upscaled Color"
      
      textures.append(IntermediateTextures(
        color: color, depth: depth, motion: motion, upscaled: upscaled))
      
      for texture in [color, depth, motion, upscaled] {
        encoder.optimizeContentsForGPUAccess(texture: texture)
      }
    }
    encoder.endEncoding()
    commandBuffer.commit()
    
    let library = try! device.makeLibrary(URL: metallibURL)
    self.initAccelBuilder(library: library)
    self.initRayTracingPipeline(library: library)
    self.initUpscaler()
  }
  
  
  func initAccelBuilder(library: MTLLibrary) {
    self.accelBuilder = MRAccelBuilder(
      device: device, commandQueue: commandQueue, library: library)
  }
  
  func initRayTracingPipeline(library: MTLLibrary) {
    // Initialize resolution and aspect ratio for rendering.
    let constants = MTLFunctionConstantValues()
    
    // Actual texture width.
    var screenWidth: UInt32 = .init(intermediateSize.x)
    constants.setConstantValue(&screenWidth, type: .uint, index: 0)
    
    // Actual texture height.
    var screenHeight: UInt32 = .init(intermediateSize.y)
    constants.setConstantValue(&screenHeight, type: .uint, index: 1)
    
    var suppressSpecular: Bool = false
    constants.setConstantValue(&suppressSpecular, type: .bool, index: 2)
    
    // Initialize the compute pipeline.
    let function = try! library.makeFunction(
      name: "renderMain", constantValues: constants)
    let desc = MTLComputePipelineDescriptor()
    desc.computeFunction = function
    desc.maxCallStackDepth = 5
    self.rayTracingPipeline = try! device
      .makeComputePipelineState(descriptor: desc, options: [], reflection: nil)
  }
  
  func initUpscaler() {
    let desc = MTLFXTemporalScalerDescriptor()
    desc.inputWidth = intermediateSize.x
    desc.inputHeight = intermediateSize.y
    desc.outputWidth = upscaledSize.x
    desc.outputHeight = upscaledSize.y
    desc.colorTextureFormat = textures[0].color.pixelFormat
    desc.depthTextureFormat = textures[0].depth.pixelFormat
    desc.motionTextureFormat = textures[0].motion.pixelFormat
    desc.outputTextureFormat = desc.colorTextureFormat
    
    desc.isAutoExposureEnabled = false
    desc.isInputContentPropertiesEnabled = false
    desc.inputContentMinScale = 2.0
    desc.inputContentMaxScale = 2.0
    
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
}

extension MRRenderer {
  // Perform any updating work that happens before encoding the rendering work.
  // This should be called as early as possible each frame, to hide any latency
  // between now and when it can encode the rendering work.
  private func updateResources() {
    self.jitterFrameID += 1
    self.jitterOffsets = makeJitterOffsets()
    self.textureIndex = (self.textureIndex + 1) % 2
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
    // If the frame has just begun, the upscaler needs to recognize that a
    // history of samples doesn't exist yet.
    upscaler.reset = self.resetScaler
    self.resetScaler = false
    
    // Bind the intermediate textures.
    let currentTextures = self.currentTextures
    upscaler.colorTexture = currentTextures.color
    upscaler.depthTexture = currentTextures.depth
    upscaler.motionTexture = currentTextures.motion
    upscaler.outputTexture = currentTextures.upscaled
    upscaler.jitterOffsetX = -self.jitterOffsets.x
    upscaler.jitterOffsetY = -self.jitterOffsets.y
    upscaler.encode(commandBuffer: commandBuffer)
    
    // Metal is forcing me to copy the upscaled texture to the drawable.
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    blitEncoder.copy(from: currentTextures.upscaled, to: drawableTexture)
    blitEncoder.endEncoding()
  }
}

extension MRRenderer {
  // If the atoms and styles were the same as last frame, the renderer recycles
  // the previous acceleration structure. Therefore, static scenes are somewhat
  // more efficient than dynamic scenes.
  //
  // If you're rendering from a dynamic scene, there is a different API with a
  // different C function. The dynamic API should be used when loading geometry
  // is resource-intensive or high-latency and therefore requires Metal IO
  // command buffers. Otherwise, the static API is sufficient to render dynamic
  // geometry.
  //
  // TODO: Instead of providing `shouldCompact` through an API, have the accel
  // builder automatically compact after it's been constant for 3 frames. You
  // don't need to store a third copy though - just a boolean of whether it was
  // the same last frame.
  public func setStaticGeometry(
    atomProvider: MRStaticAtomProvider,
    styleProvider: MRStaticStyleProvider
  ) {
    accelBuilder.currentAtoms = atomProvider.atoms
    accelBuilder.currentStyles = styleProvider.styles
  }
  
  // Only call this once per frame.
  public func setCamera(
    fovDegrees: Float,
    position: SIMD3<Float>,
    rotation: simd_float3x3,
    lightPower: Float16,
    raySampleCount: Int
  ) {
    self.previousArguments = currentArguments
    
    let maxRayHitTime: Float = 1.0 // range(0...100, 0.2)
    let minimumAmbientIllumination: Float = 0.07 // range(0...1, 0.01)
    let diffuseReflectanceScale: Float = 0.5 // range(0...1, 0.1)
    let decayConstant: Float = 2.0 // range(0...20, 0.25)
    
    self.currentArguments = Arguments(
      fovMultiplier: self.fovMultiplier(fovDegrees: fovDegrees),
      positionX: position.x,
      positionY: position.y,
      positionZ: position.z,
      rotation: rotation,
      jitter: jitterOffsets,
      frameSeed: UInt32.random(in: 0...UInt32.max),
      
      lightPower: lightPower,
      sampleCount: UInt16(raySampleCount),
      maxRayHitTime: maxRayHitTime,
      exponentialFalloffDecayConstant: decayConstant,
      minimumAmbientIllumination: minimumAmbientIllumination,
      diffuseReflectanceScale: diffuseReflectanceScale,
    
      gridWidth: 0)
  }
  
  private func fovMultiplier(fovDegrees: Float) -> Float {
    // NOTE: This currently assumes the image is square. We eventually need to
    // support rectangular image sizes for e.g. 1920x1080 video.
    
    // How many pixels exist in either direction.
    let fov90Span = 0.5 * Float(intermediateSize.x)
    
    // Larger FOV means the same ray will reach an angle farther away from the
    // center. 1 / fovSpan is larger, so fovSpan is smaller. The difference
    // should be the ratio between the tangents of the two half-angles. And
    // one side of the ratio is tan(90 / 2) = 1.0.
    let fovRadians: Float = fovDegrees * .pi / 180
    let halfAngleTangent = tan(fovRadians / 2)
    let halfAngleTangentRatio = halfAngleTangent / 1.0
    
    // Let A = fov90Span
    // Let B = pixels covered by the 45° boundary in either direction.
    // Ray = ((pixelsRight, pixelsUp) * fovMultiplier, -1)
    //
    // FOV / 2 < 45°
    // - edge of image is ray (<1, <1, -1)
    // - A = 100 pixels
    // - B = 120 pixels (off-screen)
    // - fovMultiplier = 1 / 120 = 1 / B
    // FOV / 2 = 45°
    // - edge of image is ray (1, 1, -1)
    // - fovMultiplier = unable to determine
    // FOV / 2 > 45°
    // - edge of image is ray (>1, >1, -1)
    // - A = 100 pixels
    // - B = 80 pixels (well within screen bounds)
    // - fovMultiplier = 1 / 80 = 1 / B
    
    // Next: what is B as a function of fov90Span and halfAngleTangentRatio?
    // FOV / 2 < 45°
    // - A = 100 pixels
    // - B = 120 pixels (off-screen)
    // - halfAngleTangentRatio = 0.8
    // - formula: B = A / halfAngleTangentRatio
    // FOV / 2 = 45°
    // - A = 100 pixels
    // - B = 100 pixels
    // - formula: cannot be determined
    // FOV / 2 > 45°
    // - edge of image is ray (>1, >1, -1)
    // - A = 100 pixels
    // - B = 80 pixels (well within screen bounds)
    // - halfAngleTangentRatio = 1.2
    // - formula: B = A / halfAngleTangentRatio
    //
    // fovMultiplier = 1 / B = 1 / (A / halfAngleTangentRatio)
    // fovMultiplier = halfAngleTangentRatio / fov90Span
    return halfAngleTangentRatio / fov90Span
  }
}

extension MRRenderer {
  // Eventually, we will allow presenting to a raw C pointer, instead of to a
  // display drawable. This option will require a callback, which is called
  // after the output's memory is written to.
  public func render(
    layer: CAMetalLayer,
    handler: @escaping MTLCommandBufferHandler
  ) {
    self.updateResources()
    
    // Command buffer shared between the geometry and rendering passes.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    
    // Encode the accel creation pass, if necessary.
    let accel = accelBuilder.build(
      commandBuffer: commandBuffer)
    
    // Acquire a reference to the drawable.
    let drawable = layer.nextDrawable()!
    precondition(drawable.texture.width == upscaledSize.x)
    precondition(drawable.texture.height == upscaledSize.y)
    
    // Encode the geometry data.
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    accelBuilder.buildDenseGrid(encoder: encoder)
    
    encoder.setComputePipelineState(rayTracingPipeline)
    accelBuilder.encodeGridArguments(encoder: encoder)
    accelBuilder.setGridWidth(arguments: &currentArguments!)
    withUnsafeTemporaryAllocation(
      of: Arguments.self, capacity: 2
    ) { bufferPointer in
      bufferPointer[0] = self.currentArguments!
      if let previousArguments = self.previousArguments {
        bufferPointer[1] = previousArguments
      } else {
        bufferPointer[1] = bufferPointer[0]
      }
      
      let argsLength = 2 * MemoryLayout<Arguments>.stride
      let baseAddress = bufferPointer.baseAddress!
      encoder.setBytes(baseAddress, length: argsLength, index: 0)
    }
    accelBuilder.currentStyles.withUnsafeBufferPointer {
      let length = $0.count * MemoryLayout<MRAtomStyle>.stride
      encoder.setBytes($0.baseAddress!, length: length, index: 1)
    }
    encoder.setAccelerationStructure(accel, bufferIndex: 2)

    // Encode the output textures.
    let textures = self.currentTextures
    encoder.setTextures(
      [textures.color, textures.depth, textures.motion], range: 0..<3)
    
    // Dispatch an even number of threads (the shader will rearrange them).
    let numThreadgroupsX = (intermediateSize.x + 15) / 16
    let numThreadgroupsY = (intermediateSize.y + 15) / 16
    encoder.dispatchThreadgroups(
      MTLSizeMake(numThreadgroupsX, numThreadgroupsY, 1),
      threadsPerThreadgroup: MTLSizeMake(16, 16, 1))
    encoder.endEncoding()
    
    // Encode the upscaling pass.
    upscale(commandBuffer: commandBuffer, drawableTexture: drawable.texture)
    
    // Present drawable and signal the semaphore.
    commandBuffer.present(drawable)
    commandBuffer.addCompletedHandler(handler)
    commandBuffer.commit()
  }
}