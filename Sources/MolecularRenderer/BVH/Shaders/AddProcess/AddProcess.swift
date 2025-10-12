class AddProcess {
  let process1: Shader
  
  init(device: Device, worldDimension: Float) {
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    
    shaderDesc.name = "addProcess1"
    shaderDesc.threadsPerGroup = SIMD3(128, 1, 1)
    shaderDesc.source = Self.createSource1(
      worldDimension: worldDimension)
    self.process1 = Shader(descriptor: shaderDesc)
  }
  
  static func pickPermutation() -> String {
    """
    uint pickPermutation(int3 footprintHigh) {
      uint output;
      if (footprintHigh[0] == 0) {
        output = 0;
      } else if (footprintHigh[1] == 0) {
        output = 1;
      } else {
        output = 2;
      }
      return output;
    }
    """
  }
  
  static func reorderForward() -> String {
    """
    uint3 reorderForward(uint3 loopBound, uint permutationID) {
      uint3 output;
      if (permutationID == 0) {
        output = uint3(loopBound[1], loopBound[2], loopBound[0]);
      } else if (permutationID == 1) {
        output = uint3(loopBound[0], loopBound[2], loopBound[1]);
      } else {
        output = uint3(loopBound[0], loopBound[1], loopBound[2]);
      }
      return output;
    }
    """
  }
  
  static func reorderBackward() -> String {
    """
    uint3 reorderBackward(uint3 loopBound, uint permutationID) {
      uint3 output;
      if (permutationID == 0) {
        output = uint3(loopBound[2], loopBound[0], loopBound[1]);
      } else if (permutationID == 1) {
        output = uint3(loopBound[0], loopBound[2], loopBound[1]);
      } else {
        output = uint3(loopBound[0], loopBound[1], loopBound[2]);
      }
      return output;
    }
    """
  }
  
  static func computeLoopBounds(
    worldDimension: Float
  ) -> String {
    func uint3(_ repeatedValue: Int) -> String {
      "uint3(\(repeatedValue), \(repeatedValue), \(repeatedValue))"
    }
    
    return """
    // Place the atom in the grid of 0.25 nm voxels.
    float3 scaledPosition = atom.xyz + float(\(worldDimension / 2));
    scaledPosition /= 0.25;
    float scaledRadius = sqrt(atom.w) / 0.25;
    
    // Generate the bounding box.
    float3 boxMin = floor(scaledPosition - scaledRadius);
    float3 boxMax = ceil(scaledPosition + scaledRadius);
    
    // Return early if out of bounds.
    bool3 returnEarly = boxMax > float(\(worldDimension / 0.25));
    returnEarly = \(Shader.or("returnEarly", "boxMin < 0"));
    if (any(returnEarly)) {
      return;
    }
    
    // Generate the voxel coordinates.
    uint3 smallVoxelMin = uint3(boxMin);
    uint3 smallVoxelMax = uint3(boxMax);
    uint3 largeVoxelMin = smallVoxelMin / 8;
    
    // Pre-compute the footprint.
    uint3 dividingLine = (largeVoxelMin + 1) * 8;
    dividingLine = min(dividingLine, smallVoxelMax);
    dividingLine = max(dividingLine, smallVoxelMin);
    int3 footprintLow = int3(dividingLine - smallVoxelMin);
    int3 footprintHigh = int3(smallVoxelMax - dividingLine);
    
    // Determine the loop bounds.
    uint3 loopEnd =
    \(Shader.select(uint3(1), uint3(2), "footprintHigh > 0"));
    
    // Reorder the loop traversal.
    uint permutationID = pickPermutation(footprintHigh);
    loopEnd = reorderForward(loopEnd, permutationID);
    """
  }
}
