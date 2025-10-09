struct ImageResourcesDescriptor {
  var device: Device?
  var display: Display?
  var upscaleFactor: Float?
}

class ImageResources {
  // Shaders
  let renderShader: Shader
  let upscaleShader: Shader
  
  // Memory allocations
  var cameraArgsBuffer: RingBuffer
  var previousCameraArgs: CameraArgs?
  var renderTarget: RenderTarget
  var upscaler: Upscaler?
  
  init(descriptor: ImageResourcesDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the shaders.
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    
    shaderDesc.name = "render"
    #if os(macOS)
    shaderDesc.maxTotalThreadsPerThreadgroup = 1024
    #endif
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    shaderDesc.source = RenderShader.createSource(upscaleFactor: upscaleFactor)
    self.renderShader = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "upscale"
    #if os(macOS)
    shaderDesc.maxTotalThreadsPerThreadgroup = nil
    #endif
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    shaderDesc.source = UpscaleShader.createSource(upscaleFactor: upscaleFactor)
    self.upscaleShader = Shader(descriptor: shaderDesc)
    
    // Create the memory allocations.
    self.cameraArgsBuffer = Self.createCameraArgsBuffer(device: device)
    self.previousCameraArgs = nil
    
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
