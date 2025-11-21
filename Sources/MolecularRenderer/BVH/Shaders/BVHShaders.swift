struct BVHShadersDescriptor {
  var device: Device?
  var worldDimension: Float?
}

class BVHShaders {
  let remove: RemoveProcess
  let add: AddProcess
  let rebuild: RebuildProcess
  
  let clearBuffer: Shader
  let dispatchVoxelGroups: Shader
  let resetMotionVectors: Shader
  let resetVoxelMarks: Shader
  
  init(descriptor: BVHShadersDescriptor) {
    guard let device = descriptor.device,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    self.remove = RemoveProcess(
      device: device,
      worldDimension: worldDimension)
    self.add = AddProcess(
      device: device,
      worldDimension: worldDimension)
    self.rebuild = RebuildProcess(
      device: device,
      worldDimension: worldDimension)
    
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    
    shaderDesc.name = "clearBuffer"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = ClearBuffer.createSource()
    self.clearBuffer = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "dispatchVoxelGroups"
    shaderDesc.threadsPerGroup = SIMD3(4, 4, 4)
    shaderDesc.source = DispatchVoxelGroups.createSource(
      worldDimension: worldDimension)
    self.dispatchVoxelGroups = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "resetMotionVectors"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = ResetIdle.resetMotionVectors(
      supports16BitTypes: device.supports16BitTypes)
    self.resetMotionVectors = Shader(descriptor: shaderDesc)
    
    shaderDesc.name = "resetVoxelMarks"
    shaderDesc.threadsPerGroup = SIMD3(4, 4, 4)
    shaderDesc.source = ResetIdle.resetVoxelMarks(
      worldDimension: worldDimension)
    self.resetVoxelMarks = Shader(descriptor: shaderDesc)
  }
}
