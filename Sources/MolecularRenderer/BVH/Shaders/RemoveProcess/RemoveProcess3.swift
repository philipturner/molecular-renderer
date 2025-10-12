extension RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  // threadgroup memory 16 B
  //
  // check the addressOccupiedMark of each atom in voxel
  //   if either 0 or 2, remove from the list
  // prefix sum to compact the reference list (SIMD + group reduction)
  // write to sparse.memorySlots in-place, sanitized to 128 atoms at a time
  //
  // if atoms remain, write to dense.rebuiltMarks
  // otherwise, reset entry in dense.assignedSlotIDs and sparse.assignedVoxelIDs
  static func createSource3(worldDimension: Float) -> String {
    // atoms.addressOccupiedMarks
    // voxels.dense.rebuiltMarks
    // voxels.dense.assignedSlotIDs
    // voxels.sparse.assignedVoxelIDs
    // voxels.sparse.atomsRemovedVoxelIDs
    // voxels.sparse.memorySlots
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess3(
        \(CrashBuffer.functionArguments),
        uint groupID [[threadgroup_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      groupshared uint threadgroupMemory[4];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
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
      
      let offset = GeneralCounters.offset(.atomsRemovedVoxelCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
  }
}
