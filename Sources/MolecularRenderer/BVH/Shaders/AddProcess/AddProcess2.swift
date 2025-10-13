extension AddProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // write to group.rebuiltMarks
  // scan for voxels with atoms added
  // prefix sum over the 8 counters within the voxel
  // if atoms were added, write to dense.rebuiltMarks
  // otherwise, mask out future operations for this SIMD lane
  //
  // read from dense.assignedSlotIDs
  // if a slot hasn't been assigned yet
  //   allocate new voxels (SIMD + global reduction)
  //   if exceeded memory slot limit, crash w/ diagnostic info
  //   write new entry in dense.assignedSlotIDs and sparse.assignedVoxelCoords
  //
  // add existing atom count to prefix-summed 8 counters
  // write to dense.atomicCounters
  // if new atom count is too large, crash w/ diagnostic info
  // write new atom count into memory slot header
  static func createSource2(worldDimension: Float) -> String {
    // counters.general.vacantSlotCount
    // counters.general.allocatedSlotCount
    // voxels.group.addedMarks
    // voxels.group.rebuiltMarks
    // voxels.dense.assignedSlotIDs
    // voxels.dense.atomicCounters
    // voxels.sparse.assignedVoxelCoords
    // voxels.sparse.vacantSlotIDs
    // voxels.sparse.memorySlots.headerLarge
    // voxels.sparse.memorySlots.referenceLarge
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void addProcess2(
        \(CrashBuffer.functionArguments),
        device uint *vacantSlotCount [[buffer(1)]],
        device atomic_uint *allocatedSlotCount [[buffer(2)]],
        device uint *voxelGroupAddedMarks [[buffer(3)]],
        device uint *voxelGroupRebuiltMarks [[buffer(4)]],
        device uint *assignedSlotIDs [[buffer(5)]],
        device uint4 *atomicCounters [[buffer(6)]],
        device uint *assignedVoxelCoords [[buffer(7)]],
        device uint *vacantSlotIDs [[buffer(8)]],
        device uint *memorySlots [[buffer(9)]],
        uint3 globalID [[thread_position_in_grid]],
        uint3 groupID [[threadgroup_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> vacantSlotCount : register(u1);
      RWStructuredBuffer<uint> allocatedSlotCount : register(u2);
      RWStructuredBuffer<uint> voxelGroupAddedMarks : register(u3);
      RWStructuredBuffer<uint> voxelGroupRebuiltMarks : register(u4);
      RWStructuredBuffer<uint> assignedSlotIDs : register(u5);
      RWStructuredBuffer<uint4> atomicCounters : register(u6);
      RWStructuredBuffer<uint> assignedVoxelCoords : register(u7);
      RWStructuredBuffer<uint> vacantSlotIDs : register(u8);
      RWStructuredBuffer<uint> memorySlots : register(u9);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
        "UAV(u5),"
        "UAV(u6),"
        "UAV(u7),"
        "UAV(u8),"
        "UAV(u9),"
      )]
      void addProcess2(
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
  func addProcess2(commandList: CommandList) {
    commandList.withPipelineState(shaders.add.process2) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      commandList.setBuffer(
        counters.general,
        index: 1,
        offset: GeneralCounters.offset(.vacantSlotCount))
      commandList.setBuffer(
        counters.general,
        index: 2,
        offset: GeneralCounters.offset(.allocatedSlotCount))
      
      commandList.setBuffer(
        voxels.group.addedMarks, index: 3)
      commandList.setBuffer(
        voxels.group.rebuiltMarks, index: 4)
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 5)
      commandList.setBuffer(
        voxels.dense.atomicCounters, index: 6)
      
      commandList.setBuffer(
        voxels.sparse.assignedVoxelCoords, index: 7)
      commandList.setBuffer(
        voxels.sparse.vacantSlotIDs, index: 8)
      commandList.setBuffer(
        voxels.sparse.memorySlots, index: 9)
      
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
