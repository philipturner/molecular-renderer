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
  // create a compact list of these voxel groups (SIMD + global reduction)
  //   use coordinates in grid of 8 nm voxels
  // global counter is the indirect dispatch argument
  // write to dispatchedGroupCoords8
  static func createSource(worldDimension: Float) -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void dispatchVoxelGroups(
        \(CrashBuffer.functionArguments),
        device atomic_uint *dispatchedGroupCount [[buffer(1)]],
        device uint *marks1 [[buffer(2)]],
        device uint *marks2 [[buffer(3)]],
        device uint *marks3 [[buffer(4)]],
        device uint *dispatchedGroupCoords8 [[buffer(5)]],
        uint3 globalID [[thread_position_in_grid]],
        uint3 groupID [[threadgroup_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> dispatchedGroupCount : register(u1);
      RWStructuredBuffer<uint> marks1 : register(u2);
      RWStructuredBuffer<uint> marks2 : register(u3);
      RWStructuredBuffer<uint> marks3 : register(u4);
      RWStructuredBuffer<uint> dispatchedGroupCoords8 : register(u5);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
        "UAV(u5),"
      )]
      void dispatchVoxelCoords(
        uint3 globalID : SV_DispatchThreadID,
        uint3 groupID : SV_GroupID)
      """
      #endif
    }
    
    func atomicFetchAdd() -> String {
      Reduction.atomicFetchAdd(
        buffer: "dispatchedGroupCount",
        address: "0",
        operand: "countBitsResult",
        output: "allocatedOffset")
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      if (crashBuffer[0] != 1) {
        return;
      }
      
      uint voxelGroup32ID =
      \(VoxelResources.generate("groupID", worldDimension / 32));
      uint voxelGroup8ID =
      \(VoxelResources.generate("globalID", worldDimension / 8));
      
      // scan for marked voxel groups
      bool needsDispatch = false;
      if (marks1[voxelGroup8ID]) {
        needsDispatch = true;
      }
      if (marks2[voxelGroup8ID]) {
        needsDispatch = true;
      }
      if (marks3[voxelGroup8ID]) {
        needsDispatch = true;
      }
      uint countBitsResult = \(Reduction.waveActiveCountBits("needsDispatch"));
      if (countBitsResult == 0) {
        return;
      }
      
      // create a compact list of these voxel groups
      uint allocatedOffset = \(UInt32.max);
      if (\(Reduction.waveIsFirstLane())) {
        \(atomicFetchAdd())
      }
      allocatedOffset =
      \(Reduction.waveReadLaneAt("allocatedOffset", laneID: 0));
      
      allocatedOffset += \(Reduction.wavePrefixSum("uint(needsDispatch)"));
      if (needsDispatch) {
        uint encoded = \(VoxelResources.encode("globalID"));
        rebuiltVoxelCoords[allocatedOffset] = encoded;
      }
    }
    """
  }
}
