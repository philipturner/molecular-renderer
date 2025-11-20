class RebuildProcess {
  let process1: Shader
  let process2: Shader
  let process3: Shader
  
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
      worldDimension: worldDimension,
      vendor: device.vendor,
      supports16BitTypes: device.supports16BitTypes)
    self.process2 = Shader(descriptor: shaderDesc)

    shaderDesc.name = "rebuildProcess3"
    shaderDesc.threadsPerGroup = SIMD3(4, 4, 4)
    shaderDesc.source = Self.createSource3(
      worldDimension: worldDimension)
    self.process3 = Shader(descriptor: shaderDesc)
  }
  
  static func cubeSphereTest() -> String {
    """
    bool cubeSphereTest(float3 lowerCorner, float4 atom) {
      float3 c1 = lowerCorner;
      float3 c2 = c1 + 1;
      float3 delta_c1 = atom.xyz - c1;
      float3 delta_c2 = atom.xyz - c2;
      
      float dist_squared = atom.w;
      \(Shader.unroll)
      for (uint dim = 0; dim < 3; ++dim) {
        if (atom[dim] < c1[dim]) {
          dist_squared -= delta_c1[dim] * delta_c1[dim];
        } else if (atom[dim] > c2[dim]) {
          dist_squared -= delta_c2[dim] * delta_c2[dim];
        }
      }
      
      return dist_squared > 0;
    }
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
