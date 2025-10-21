extension RebuildProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  //
  // read from dense.assignedSlotIDs
  //   do not use any optimizations to reduce the bandwidth cost
  // write to group.occupiedMarks
  static func createSource3(worldDimension: Float) -> String {
    // voxels.group.occupiedMarks8
    // voxels.group.occupiedMarks32
    // voxels.dense.assignedSlotIDs
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void rebuildProcess3(
        device uint *voxelGroup8OccupiedMarks [[buffer(0)]],
        device uint *voxelGroup32OccupiedMarks [[buffer(1)]],
        device uint *assignedSlotIDs [[buffer(2)]],
        uint3 voxelCoords [[thread_position_in_grid]])
      """
      #else
      """
      RWStructuredBuffer<uint> voxelGroup8OccupiedMarks : register(u0);
      RWStructuredBuffer<uint> voxelGroup32OccupiedMarks : register(u1);
      RWStructuredBuffer<uint> assignedSlotIDs : register(u2);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        "UAV(u0),"
        "UAV(u1),"
        "UAV(u2),"
      )]
      void rebuildProcess3(
        uint3 voxelCoords : SV_DispatchThreadID)
      """
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      uint voxelID =
      \(VoxelResources.generate("voxelCoords", worldDimension / 2));
      
      // read from dense.assignedSlotIDs
      uint slotID = assignedSlotIDs[voxelID];
      if (slotID == \(UInt32.max)) {
        return;
      }
      
      uint3 voxelGroup8Coords = voxelCoords / 4;
      uint3 voxelGroup32Coords = voxelCoords / 16;
      uint voxelGroup8ID =
      \(VoxelResources.generate("voxelGroup8Coords", worldDimension / 8));
      uint voxelGroup32ID =
      \(VoxelResources.generate("voxelGroup32Coords", worldDimension / 32));
      
      // write to group.occupiedMarks
      voxelGroup8OccupiedMarks[voxelGroup8ID] = 1;
      voxelGroup32OccupiedMarks[voxelGroup32ID] = 1;
    }
    """
  }
}

extension BVHBuilder {
  func rebuildProcess3(commandList: CommandList) {
    commandList.withPipelineState(shaders.rebuild.process3) {
      commandList.setBuffer(
        voxels.group.occupiedMarks8, index: 0)
      commandList.setBuffer(
        voxels.group.occupiedMarks32, index: 1)
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 2)
      
      let gridSize = Int(voxels.worldDimension / 8)
      let threadgroupCount = SIMD3<UInt32>(
        UInt32(gridSize),
        UInt32(gridSize),
        UInt32(gridSize))
      commandList.dispatch(groups: threadgroupCount)
    }
  }
}
