extension RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  // threadgroup memory 16 B
  //
  // check the addressOccupiedMark of each atom in voxel
  //   if either 0 or 2, remove from the list
  // prefix sum to compact the reference list (SIMD + group reduction)
  // write to sparse.memorySlots in-place, sanitized to 128 atoms at a time
  // write new atom count into memory slot header
  //
  // if atoms remain, write to dense.rebuiltMarks
  // otherwise, reset entry in dense.assignedSlotIDs and sparse.assignedVoxelIDs
  static func createSource3(worldDimension: Float) -> String {
    // atoms.addressOccupiedMarks
    // voxels.dense.assignedSlotIDs
    // voxels.dense.rebuiltMarks
    // voxels.sparse.assignedVoxelIDs
    // voxels.sparse.atomsRemovedVoxelIDs
    // voxels.sparse.memorySlots.headerLarge
    // voxels.sparse.memorySlots.referenceLarge
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess3(
        \(CrashBuffer.functionArguments),
        device uint *assignedSlotIDs [[buffer(1)]],
        device uchar *rebuiltMarks [[buffer(2)]],
        device uint *assignedVoxelIDs [[buffer(3)]],
        device uint *atomsRemovedVoxelIDs [[buffer(4)]],
        device uint *memorySlots [[buffer(5)]],
        uint groupID [[threadgroup_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> assignedSlotIDs : register(u1);
      RWBuffer<uint> rebuiltMarks : register(u2);
      RWStructuredBuffer<uint> assignedVoxelIDs : register(u3);
      RWStructuredBuffer<uint> atomsRemovedVoxelIDs : register(u4);
      RWStructuredBuffer<uint> memorySlots : register(u5);
      groupshared uint threadgroupMemory[4];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "DescriptorTable(UAV(u2, numDescriptors = 1)),"
        "UAV(u3),"
        "UAV(u4),"
        "UAV(u5),"
      )]
      void removeProcess3(
        uint groupID : SV_GroupID,
        uint localID : SV_GroupThreadID)
      """
      #endif
    }
    
    func allocateThreadgroupMemory() -> String {
      #if os(macOS)
      "threadgroup uint threadgroupMemory[4];"
      #else
      ""
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      \(allocateThreadgroupMemory())
      
      if (crashBuffer[0] != 1) {
        return;
      }
    }
    """
  }
}

extension BVHBuilder {
  func removeProcess3(commandList: CommandList) {
    commandList.withPipelineState(shaders.remove.process3) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 1)
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.rebuiltMarks, index: 2)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.rebuiltMarksHandleID, index: 2)
      #endif
      
      commandList.setBuffer(
        voxels.sparse.assignedVoxelIDs, index: 3)
      commandList.setBuffer(
        voxels.sparse.atomsRemovedVoxelIDs, index: 4)
      commandList.setBuffer(
        voxels.sparse.memorySlots, index: 5)
      
      let offset = GeneralCounters.offset(.atomsRemovedVoxelCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
  }
}
