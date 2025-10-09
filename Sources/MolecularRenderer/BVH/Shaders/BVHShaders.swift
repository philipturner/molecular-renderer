struct BVHShadersDescriptor {
  var device: Device?
}

class BVHShaders {
  let clearBuffer: Shader
  let debugDiagnostic: Shader
  let removeProcess1: Shader
  
  init(descriptor: BVHShadersDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    
    shaderDesc.name = "clearBuffer"
    #if os(macOS)
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    #endif
    shaderDesc.source = ClearBuffer.createSource()
    self.clearBuffer = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "debugDiagnostic"
    #if os(macOS)
    shaderDesc.threadsPerGroup = SIMD3(1, 1, 1)
    #endif
    shaderDesc.source = DebugDiagnostic.createSource()
    self.debugDiagnostic = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "removeProcess1"
    #if os(macOS)
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    #endif
    shaderDesc.source = RemoveProcess.createSource1()
    self.removeProcess1 = Shader(descriptor: shaderDesc)
    
    
  }
}
