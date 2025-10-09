struct BVHShadersDescriptor {
  var device: Device?
}

class BVHShaders {
  let clearBuffer: Shader
  let debugDiagnostic: Shader
  let removeProcess1: Shader
  let addProcess1: Shader
  
  init(descriptor: BVHShadersDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    
    shaderDesc.name = "clearBuffer"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = ClearBuffer.createSource()
    self.clearBuffer = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "debugDiagnostic"
    shaderDesc.threadsPerGroup = SIMD3(1, 1, 1)
    shaderDesc.source = DebugDiagnostic.createSource()
    self.debugDiagnostic = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "removeProcess1"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = RemoveProcess.createSource1()
    self.removeProcess1 = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "addProcess1"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = AddProcess.createSource1()
    self.addProcess1 = Shader(descriptor: shaderDesc)
  }
}
