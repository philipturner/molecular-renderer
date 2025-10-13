extension RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  // threadgroup memory 20 B
  //
  // check the addressOccupiedMark of each atom in voxel
  //   if either 0 or 2, remove from the list
  // prefix sum to compact the reference list (SIMD + group reduction)
  // write to sparse.memorySlots in-place, sanitized to 128 atoms at a time
  // write new atom count into memory slot header
  //
  // if atoms remain, write to dense.rebuiltMarks
  // otherwise
  //   reset entry in dense.assignedSlotIDs and sparse.assignedVoxelCoords
  static func createSource3(worldDimension: Float) -> String {
    // atoms.addressOccupiedMarks // TODO
    // voxels.dense.assignedSlotIDs
    // voxels.dense.rebuiltMarks
    // voxels.sparse.assignedVoxelCoords
    // voxels.sparse.atomsRemovedVoxelCoords
    // voxels.sparse.memorySlots.headerLarge
    // voxels.sparse.memorySlots.referenceLarge
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess3(
        \(CrashBuffer.functionArguments),
        device uchar *addressOccupiedMarks [[buffer(1)]],
        device uint *assignedSlotIDs [[buffer(2)]],
        device uchar *rebuiltMarks [[buffer(3)]],
        device uint *assignedVoxelCoords [[buffer(4)]],
        device uint *atomsRemovedVoxelCoords [[buffer(5)]],
        device uint *memorySlots [[buffer(6)]],
        uint groupID [[threadgroup_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWBuffer<uint> addressOccupiedMarks : register(u1);
      RWStructuredBuffer<uint> assignedSlotIDs : register(u2);
      RWBuffer<uint> rebuiltMarks : register(u3);
      RWStructuredBuffer<uint> assignedVoxelCoords : register(u4);
      RWStructuredBuffer<uint> atomsRemovedVoxelCoords : register(u5);
      RWStructuredBuffer<uint> memorySlots : register(u6);
      groupshared uint threadgroupMemory[4];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "DescriptorTable(UAV(u1, numDescriptors = 1)),"
        "UAV(u2),"
        "DescriptorTable(UAV(u3, numDescriptors = 1)),"
        "UAV(u4),"
        "UAV(u5),"
        "UAV(u6),"
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
      
      #if os(macOS)
      commandList.setBuffer(
        atoms.addressOccupiedMarks, index: 1)
      #else
      commandList.setDescriptor(
        handleID: atoms.addressOccupiedMarksHandleID, index: 1)
      #endif
      
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 2)
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.rebuiltMarks, index: 3)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.rebuiltMarksHandleID, index: 3)
      #endif
      
      commandList.setBuffer(
        voxels.sparse.assignedVoxelCoords, index: 4)
      commandList.setBuffer(
        voxels.sparse.atomsRemovedVoxelCoords, index: 5)
      commandList.setBuffer(
        voxels.sparse.memorySlots, index: 6)
      
      let offset = GeneralCounters.offset(.atomsRemovedVoxelCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
  }
}
