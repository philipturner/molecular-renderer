#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct ResourcesDescriptor {
  var device: Device?
  var renderTarget: RenderTarget?
}

// Generic resources container for resources used during rendering.
//
// TODO: Rename this to ImageResources and migrate to the Image folder.
class Resources {
  let renderShader: Shader
  let upscaleShader: Shader
    
  var cameraArgsBuffer: RingBuffer
  var previousCameraArgs: CameraArgs?
  
  init(descriptor: ResourcesDescriptor) {
    guard let device = descriptor.device,
          let renderTarget = descriptor.renderTarget else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the shaders.
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    #if os(macOS)
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    #endif
    
    shaderDesc.source = RenderShader.createSource(
      upscaleFactor: renderTarget.upscaleFactor)
    shaderDesc.name = "render"
    self.renderShader = Shader(descriptor: shaderDesc)
    
    shaderDesc.source = UpscaleShader.createSource(
      upscaleFactor: renderTarget.upscaleFactor)
    shaderDesc.name = "upscale"
    self.upscaleShader = Shader(descriptor: shaderDesc)
    
    // Create the memory allocations.
    self.cameraArgsBuffer = Self.createCameraArgsBuffer(device: device)
    self.previousCameraArgs = nil
    
    // TODO: Create the render target here.
    
    #if os(Windows)
    // Encode the render target in the descriptor heap.
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
