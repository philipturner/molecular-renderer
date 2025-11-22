struct ImageResourcesDescriptor {
  var device: Device?
  var display: Display?
  var memorySlotCount: Int?
  var upscaleFactor: Float?
  var worldDimension: Float?
}

class ImageResources {
  let renderShader: Shader
  let upscaleShader: Shader

  let renderTarget: RenderTarget
  let upscaler: Upscaler?
  
  var cameraArgsBuffer: RingBuffer
  var previousCameraArgs: CameraArgs?
  
  init(descriptor: ImageResourcesDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    self.renderShader = Self.createRenderShader(descriptor: descriptor)
    self.upscaleShader = Self.createUpscaleShader(descriptor: descriptor)

    var renderTargetDesc = RenderTargetDescriptor()
    renderTargetDesc.device = device
    renderTargetDesc.display = display
    renderTargetDesc.upscaleFactor = upscaleFactor
    self.renderTarget = RenderTarget(descriptor: renderTargetDesc)
    
    if upscaleFactor > 1 {
      var upscalerDesc = UpscalerDescriptor()
      upscalerDesc.device = device
      upscalerDesc.display = display
      upscalerDesc.upscaleFactor = upscaleFactor
      self.upscaler = Upscaler(descriptor: upscalerDesc)
    } else {
      self.upscaler = nil
    }
    
    self.cameraArgsBuffer = Self.createCameraArgsBuffer(device: device)
    self.previousCameraArgs = nil
  }

  private static func createRenderShader(
    descriptor: ImageResourcesDescriptor
  ) -> Shader {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let memorySlotCount = descriptor.memorySlotCount,
          let upscaleFactor = descriptor.upscaleFactor,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }

    var renderShaderDesc = RenderShaderDescriptor()
    renderShaderDesc.isOffline = display.isOffline
    renderShaderDesc.memorySlotCount = memorySlotCount
    renderShaderDesc.supports16BitTypes = device.supports16BitTypes
    renderShaderDesc.upscaleFactor = upscaleFactor
    renderShaderDesc.worldDimension = worldDimension
    let renderShaderSource = RenderShader.createSource(
      descriptor: renderShaderDesc)
    
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    shaderDesc.name = "render"
    #if os(macOS)
    shaderDesc.maxTotalThreadsPerThreadgroup = 1024
    #endif
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    shaderDesc.source = renderShaderSource
    return Shader(descriptor: shaderDesc)
  }

  private static func createUpscaleShader(
    descriptor: ImageResourcesDescriptor
  ) -> Shader {
    guard let device = descriptor.device,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }

    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    shaderDesc.name = "upscale"
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    shaderDesc.source = UpscaleShader.createSource(
      upscaleFactor: upscaleFactor)
    return Shader(descriptor: shaderDesc)
  }
  
  private static func createCameraArgsBuffer(
    device: Device
  ) -> RingBuffer {
    var ringBufferDesc = RingBufferDescriptor()
    ringBufferDesc.accessLevel = .constant
    ringBufferDesc.device = device
    ringBufferDesc.size = MemoryLayout<CameraArgs>.stride * 2
    return RingBuffer(descriptor: ringBufferDesc)
  }
}
