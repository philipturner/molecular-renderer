extension RebuildProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // scan for rebuilt voxels
  // create a compact list of these voxels (SIMD + global reduction)
  // global counter is the indirect dispatch argument
  // write to sparse.rebuiltVoxelCoords
  //
  // read from dense.assignedSlotIDs
  //   do not use any optimizations to reduce the bandwidth cost
  // write to group.occupiedMarks
  static func createSource1(worldDimension: Float) -> String {
    // counters.general.rebuiltVoxelCount
    // voxels.group.rebuiltMarks
    // voxels.group.occupiedMarks
    // voxels.dense.assignedSlotIDs
    // voxels.sparse.rebuiltVoxelCoords
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void rebuildProcess1(
        \(CrashBuffer.functionArguments),
        device atomic_uint *rebuiltVoxelCount [[buffer(1)]],
        device uint *voxelGroupRebuiltMarks [[buffer(2)]],
        device uint *voxelGroupOccupiedMarks [[buffer(3)]],
        device uint *assignedSlotIDs [[buffer(4)]],
        device uint *rebuiltVoxelCoords [[buffer(5)]],
        uint3 globalID [[thread_position_in_grid]],
        uint3 groupID [[threadgroup_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> rebuiltVoxelCount : register(u1);
      RWStructuredBuffer<uint> voxelGroupRebuiltMarks : register(u2);
      RWStructuredBuffer<uint> voxelGroupOccupiedMarks : register(u3);
      RWStructuredBuffer<uint> assignedSlotIDs : register(u4);
      RWStructuredBuffer<uint> rebuiltVoxelCoords : register(u5);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
        "UAV(u5),"
      )]
      void rebuildProcess1(
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
    }
    """
  }
}

extension BVHBuilder {
  func rebuildProcess1(commandList: CommandList) {
    commandList.withPipelineState(shaders.rebuild.process1) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      commandList.setBuffer(
        counters.general,
        index: 1,
        offset: GeneralCounters.offset(.rebuiltVoxelCount))
      commandList.setBuffer(
        voxels.group.rebuiltMarks, index: 2)
      commandList.setBuffer(
        voxels.group.occupiedMarks, index: 3)
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 4)
      commandList.setBuffer(
        voxels.sparse.rebuiltVoxelCoords, index: 5)
      
      let gridSize = Int(voxels.worldDimension / 8)
      let threadgroupCount = SIMD3<UInt32>(
        UInt32(gridSize),
        UInt32(gridSize),
        UInt32(gridSize))
      commandList.dispatch(groups: threadgroupCount)
    }
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
