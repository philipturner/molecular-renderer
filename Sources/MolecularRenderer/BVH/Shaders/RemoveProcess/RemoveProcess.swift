class RemoveProcess {
  let process1: Shader
  let process2: Shader
  let process3: Shader
  let process4: Shader
  
  init(device: Device, worldDimension: Float) {
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    
    shaderDesc.name = "removeProcess1"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = Self.createSource1(
      worldDimension: worldDimension)
    self.process1 = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "removeProcess2"
    shaderDesc.threadsPerGroup = SIMD3(4, 4, 4)
    shaderDesc.source = Self.createSource2(
      worldDimension: worldDimension)
    self.process2 = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "removeProcess3"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = Self.createSource3(
      worldDimension: worldDimension)
    self.process3 = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "removeProcess4"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = Self.createSource4()
    self.process4 = Shader(descriptor: shaderDesc)
  }
}
