struct ImageResourcesDescriptor {
  var device: Device?
  var display: Display?
  var upscaleFactor: Float?
  var worldDimension: Float?
}

class ImageResources {
  let renderShader: Shader
  let renderTarget: RenderTarget // TODO: Make this optional
  let upscaler: Upscaler?
  
  var cameraArgsBuffer: RingBuffer
  var previousCameraArgs: CameraArgs?
  
  init(descriptor: ImageResourcesDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    shaderDesc.name = "render"
    #if os(macOS)
    shaderDesc.maxTotalThreadsPerThreadgroup = 1024
    #endif
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    shaderDesc.source = RenderShader.createSource(
      upscaleFactor: upscaleFactor,
      worldDimension: worldDimension)
    self.renderShader = Shader(descriptor: shaderDesc)
    
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
