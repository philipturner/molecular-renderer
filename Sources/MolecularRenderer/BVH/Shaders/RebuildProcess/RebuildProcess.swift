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
  
  static func cubeSphereTest() -> String {
    """
    
    """
  }
  
  static func computeLoopBounds() -> String {
    """
    // Place the atom in the grid of 0.25 nm voxels.
    atom.xyz -= lowerCorner;
    atom.xyz /= 0.25;
    atom.w /= (0.25 * 0.25);
    
    // Generate the bounding box.
    float radius = sqrt(atom.w);
    float3 boxMin = atom.xyz - radius;
    float3 boxMax = atom.xyz + radius;
    boxMin = max(boxMin, 0);
    boxMax = min(boxMax, 8);
    boxMin = floor(boxMin);
    boxMax = ceil(boxMax);
    """
  }
}
