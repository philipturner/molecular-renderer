struct DispatchVoxelGroups {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 8)
  // dispatch groups  SIMD3(repeating: worldDimension / 32)
  //
  // Affected kernels:
  // - addProcess2
  // - removeProcess2
  // - rebuildProcess1
  // - resetIdle
  //
  // scan for marked voxel groups
  // create a compact list of cooordinates in grid of 8 nm voxels
  // global counter is the indirect dispatch argument
  // write to dispatchedCoords8
  static func createSource(worldDimension: Float) -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void dispatchVoxelGroups(
        \(CrashBuffer.functionArguments),
        device uint *marks1 [[buffer(1)]],
        device uint *marks2 [[buffer(2)]],
        device uint *marks3 [[buffer(3)]],
        device uint *dispatchedCoords8 [[buffer(4)]],
        uint3 globalID [[thread_position_in_grid]],
        uint3 groupID [[threadgroup_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> marks1 : register(u1);
      RWStructuredBuffer<uint> marks2 : register(u2);
      RWStructuredBuffer<uint> marks3 : register(u3);
      RWStructuredBuffer<uint> dispatchedCoords : register(u4);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
      )]
      void dispatchVoxelCoords(
        uint3 globalID : SV_DispatchThreadID,
        uint3 groupID : SV_GroupID)
      """
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      if (crashBuffer[0] != 1) {
        return;
      }
      
      uint voxelGroup32ID =
      \(VoxelResources.)
    }
    """
  }
}
