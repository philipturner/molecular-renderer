class RebuildProcess {
  let process1: Shader
  let process2: Shader
  
  init(device: Device, worldDimension: Float) {
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    
    shaderDesc.name = "rebuildProcess1"
    shaderDesc.threadsPerGroup = SIMD3(4, 4, 4)
    shaderDesc.source = Self.createSource1(
      worldDimension: worldDimension)
    self.process1 = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "rebuildProcess2"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = Self.createSource2(
      worldDimension: worldDimension)
    self.process2 = Shader(descriptor: shaderDesc)
  }
}
