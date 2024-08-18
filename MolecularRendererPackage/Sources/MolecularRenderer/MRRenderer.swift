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
  // Renderer configuration variables.
  var offline: Bool
  var useMotionVectors: Bool
  var upscaleFactor: Int?
  var intermediateSize: SIMD2<Int>
  
  // Per-frame state variables.
  var jitterFrameID: Int = 0
  var jitterOffsets: SIMD2<Float> = .zero
  var textureIndex: Int = 0
  
  // Properties that track the frame ID.
  var renderIndex: Int = 0
  var resetTracker: ResetTracker = .init()
  
  // Objects that supply data to the renderer.
  var atomProvider: MRAtomProvider!
  var atomStyleProvider: MRAtomStyleProvider!
  var camera: MRCamera!
  var lights: [MRLight]!
  var quality: MRQuality!
  var time: MRTime!
  
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
  var lightsBuffer: MTLBuffer
  
  // Enter the width and height of the texture to present, not the resolution
  // you expect the internal GPU shader to write to.
  public init(descriptor: MRRendererDescriptor) {
    // Initialize Metal resources.
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!
    descriptor.assertValid()
    
    self.offline = descriptor.offline
    self.useMotionVectors = descriptor.useMotionVectors
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
    
    if !offline {
      initUpscaler()
    }
    initRayTracer(library: library)
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
    
    var voxel_width_denom: Float = 16
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
}
