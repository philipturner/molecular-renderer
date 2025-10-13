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
  //   initialize atom count to 0 in memory slot header
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
    // voxels.dense.rebuiltMarks
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
        device uchar *rebuiltMarks [[buffer(6)]],
        device uint4 *atomicCounters [[buffer(7)]],
        device uint *assignedVoxelCoords [[buffer(8)]],
        device uint *vacantSlotIDs [[buffer(9)]],
        device uint *memorySlots [[buffer(10)]],
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
      RWBuffer<uint> rebuiltMarks : register(u6);
      RWStructuredBuffer<uint4> atomicCounters : register(u7);
      RWStructuredBuffer<uint> assignedVoxelCoords : register(u8);
      RWStructuredBuffer<uint> vacantSlotIDs : register(u9);
      RWStructuredBuffer<uint> memorySlots : register(u10);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
        "UAV(u5),"
        "DescriptorTable(UAV(u6, numDescriptors = 1)),"
        "UAV(u7),"
        "UAV(u8),"
        "UAV(u9),"
        "UAV(u10),"
      )]
      void addProcess2(
        uint3 globalID : SV_DispatchThreadID,
        uint3 groupID : SV_GroupID)
      """
      #endif
    }
    
    func process(counters: String) -> String {
      """
      \(Shader.unroll)
      for (uint i = 0; i < 4; ++i) {
        uint temp = \(counters)[i];
        \(counters)[i] = addedAtomCount;
        addedAtomCount += temp;
      }
      """
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      if (crashBuffer[0] != 1) {
        return;
      }
      
      uint voxelGroupID =
      \(VoxelResources.generate("groupID", worldDimension / 8));
      uint voxelID =
      \(VoxelResources.generate("globalID", worldDimension / 2));
      
      if (voxelGroupAddedMarks[voxelGroupID] == 0) {
        return;
      }
      voxelGroupRebuiltMarks[voxelGroupID] = 1;
      
      uint4 counters1 = atomicCounters[2 * voxelID + 0];
      uint4 counters2 = atomicCounters[2 * voxelID + 1];
      uint addedAtomCount = 0;
      \(process(counters: "counters1"))
      \(process(counters: "counters2"))
      if (addedAtomCount > 0) {
        rebuiltMarks[voxelID] = 1;
      }
      
      // Next step: debug compare_exchange_explicit accesses to the global
      // crash buffer.
      if (addedAtomCount > 0) {
        bool acquiredLock = false;
        \(CrashBuffer.acquireLock(errorCode: 2))
        if (acquiredLock) {
          crashBuffer[1] = voxelID;
          crashBuffer[2] = globalID.x;
          crashBuffer[3] = globalID.y;
          crashBuffer[4] = globalID.z;
          crashBuffer[5] = addedAtomCount;
          
          // Mostly just for the purpose of testing encode/decode at the moment.
          uint encoded = \(VoxelResources.encode("globalID"));
          crashBuffer[6] = encoded;
          
        }
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
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.rebuiltMarks, index: 6)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.rebuiltMarksHandleID, index: 6)
      #endif
      
      commandList.setBuffer(
        voxels.dense.atomicCounters, index: 7)
      commandList.setBuffer(
        voxels.sparse.assignedVoxelCoords, index: 8)
      commandList.setBuffer(
        voxels.sparse.vacantSlotIDs, index: 9)
      commandList.setBuffer(
        voxels.sparse.memorySlots, index: 10)
      
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
