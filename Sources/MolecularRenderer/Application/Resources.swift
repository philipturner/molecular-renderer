#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct ResourcesDescriptor {
  var device: Device?
  #if os(Windows)
  var descriptorHeap: DescriptorHeap?
  #endif
  var display: Display?
  var upscaleFactor: Float?
}

// Generic resources container for resources used during rendering.
//
// TODO: Rename this to ImageResources and migrate to the Image folder.
class Resources {
  // Shaders
  let renderShader: Shader
  let upscaleShader: Shader
    
  // Memory allocations
  var cameraArgsBuffer: RingBuffer
  var previousCameraArgs: CameraArgs?
  var renderTarget: RenderTarget?
  var upscaler: Upscaler?
  
  init(descriptor: ResourcesDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    #if os(Windows)
    guard let descriptorHeap = descriptor.descriptorHeap else {
      fatalError("Descriptor was incomplete.")
    }
    #endif
    
    // Create the shaders.
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    #if os(macOS)
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    #endif
    
    shaderDesc.source = RenderShader.createSource(upscaleFactor: upscaleFactor)
    shaderDesc.name = "render"
    self.renderShader = Shader(descriptor: shaderDesc)
    
    shaderDesc.source = UpscaleShader.createSource(upscaleFactor: upscaleFactor)
    shaderDesc.name = "upscale"
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
    
    #if os(Windows)
    // Bind the render target to the descriptor heap.
    renderTarget.encode(
      descriptorHeap: descriptorHeap,
      offset: 0)
    #endif
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
