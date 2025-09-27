struct ResourcesDescriptor {
  var device: Device?
  var renderTarget: RenderTarget?
}

// A temporary measure to organize the large number of resources
// formerly in 'main.swift'.
public class Resources {
  public let shader: Shader
  
  init(descriptor: ResourcesDescriptor) {
    guard let device = descriptor.device,
          let renderTarget = descriptor.renderTarget else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Set up the shader.
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    shaderDesc.name = "renderImage"
    shaderDesc.source = RenderImage.createSource()
    #if os(macOS)
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    #endif
    self.shader = Shader(descriptor: shaderDesc)
  }
}
