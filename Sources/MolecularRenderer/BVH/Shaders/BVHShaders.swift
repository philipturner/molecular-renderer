struct BVHShadersDescriptor {
  var device: Device?
  var worldDimension: Float?
}

class BVHShaders {
  let clearBuffer: Shader
  let debugDiagnostic: Shader
  
  let removeProcess1: Shader
  let addProcess1: Shader
  
  let resetMotionVectors: Shader
  let resetVoxelMarks: Shader
  
  init(descriptor: BVHShadersDescriptor) {
    guard let device = descriptor.device,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    
    shaderDesc.name = "clearBuffer"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = ClearBuffer.createSource()
    self.clearBuffer = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "debugDiagnostic"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = DebugDiagnostic.createSource()
    self.debugDiagnostic = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "removeProcess1"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = RemoveProcess.createSource1()
    self.removeProcess1 = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "addProcess1"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = AddProcess.createSource1(
      worldDimension: worldDimension)
    self.addProcess1 = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "resetMotionVectors"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = ResetIdle.resetMotionVectors()
    self.resetMotionVectors = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "resetVoxelMarks"
    shaderDesc.threadsPerGroup = SIMD3(4, 4, 4)
    shaderDesc.source = ResetIdle.resetVoxelMarks(
      worldDimension: worldDimension)
    self.resetVoxelMarks = Shader(descriptor: shaderDesc)
  }
}
