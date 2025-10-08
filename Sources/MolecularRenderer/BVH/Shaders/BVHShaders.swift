struct BVHShadersDescriptor {
  var device: Device?
}

class BVHShaders {
  let clearBuffer: Shader
  let debugDiagnostic: Shader
  
  init(descriptor: BVHShadersDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    
    var shaderDesc = ShaderDescriptor()
    fatalError("Not implemented.")
  }
}
