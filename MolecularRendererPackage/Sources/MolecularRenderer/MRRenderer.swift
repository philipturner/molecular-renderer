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
  var intermediateTextureSize: Int
  var upscaleFactor: Int
  
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
  var renderPipeline: MTLComputePipelineState!
  
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
  static var framesInFlight: Int { 2 }
  var textures: [IntermediateTextures] = []
  var currentTextures: IntermediateTextures {
    // TODO: Remove this computed property, index into the buffer explicitly.
    self.textures[jitterFrameID % Self.framesInFlight]
  }
  
  // Cache previous arguments to generate motion vectors.
  var previousArguments: Arguments?
  var currentArguments: Arguments?
  var lightsBuffer: MTLBuffer
  
  // Enter the width and height of the texture to present, not the resolution
  // you expect the internal GPU shader to write to.
  public init(descriptor: MRRendererDescriptor) {
    guard let url = descriptor.url,
          let intermediateTextureSize = descriptor.intermediateTextureSize,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    self.intermediateTextureSize = intermediateTextureSize
    self.upscaleFactor = upscaleFactor
    
    // Initialize Metal resources.
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!
    
    // Ensure the textures use lossless compression.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeBlitCommandEncoder()!
    
    for _ in 0..<Self.framesInFlight {
      let desc = MTLTextureDescriptor()
      desc.storageMode = .private
      desc.usage = [ .shaderWrite, .shaderRead ]
      
      desc.width = intermediateTextureSize
      desc.height = intermediateTextureSize
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
      desc.width = intermediateTextureSize * upscaleFactor
      desc.height = intermediateTextureSize * upscaleFactor
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
    
    let lightsBufferLength = 3 * 8 * MemoryLayout<MRLight>.stride
    precondition(MemoryLayout<MRLight>.stride == 16)
    self.lightsBuffer = device.makeBuffer(length: lightsBufferLength)!
    
    let library = try! device.makeLibrary(URL: descriptor.url!)
    self.accelBuilder = MRAccelBuilder(renderer: self, library: library)
    accelBuilder.reportPerformance = descriptor.reportPerformance
    
    initUpscaler()
    initRayTracer(library: library)
  }
  
  func initUpscaler() {
    let desc = MTLFXTemporalScalerDescriptor()
    desc.inputWidth = intermediateTextureSize
    desc.inputHeight = intermediateTextureSize
    desc.outputWidth = intermediateTextureSize * upscaleFactor
    desc.outputHeight = intermediateTextureSize * upscaleFactor
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
    let constants = MTLFunctionConstantValues()
    var screenWidth = UInt32(intermediateTextureSize)
    var screenHeight = UInt32(intermediateTextureSize)
    constants.setConstantValue(&screenWidth, type: .uint, index: 0)
    constants.setConstantValue(&screenHeight, type: .uint, index: 1)
    
    let function = try! library.makeFunction(
      name: "renderAtoms", constantValues: constants)
    
    let desc = MTLComputePipelineDescriptor()
    desc.computeFunction = function
    desc.maxTotalThreadsPerThreadgroup = 1024
    self.renderPipeline = try! device.makeComputePipelineState(
      descriptor: desc, options: [], reflection: nil)
  }
}
