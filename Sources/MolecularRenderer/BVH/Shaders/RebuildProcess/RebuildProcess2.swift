extension RebuildProcess {
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  // threadgroup memory 2064 B
  //
  // read voxel ID from sparse.rebuiltVoxelIDs
  // decode voxel lower corner from ID
  // read atom count from sparse.memorySlots.headerLarge
  //
  // # Phase I
  //
  // loop over the cuboid bounding box of each atom
  // atomically accumulate into threadgroupCounters
  //
  // # Phase II
  //
  // read 4 voxels in a single instruction, on 128 threads in parallel
  // prefix sum over 512 small voxels (SIMD + group reduction)
  //   save the prefix sum result for Phase IV
  // if reference count is too large, crash w/ diagnostic info
  // write reference count into memory slot header
  //
  // # Phase III
  //
  // loop over a 3x3x3 grid of small voxels for each atom
  // run the cube-sphere test and mask out voxels outside the 2 nm bound
  // atomically accumulate into threadgroupCounters
  // write a 16-bit reference to sparse.memorySlots
  //
  // # Phase IV
  //
  // restore the prefix sum result
  // read end of reference list from threadgroupCounters
  // if atom count is zero, output UInt32(0)
  // otherwise
  //   store two offsets relative to the slot's region for 16-bit references
  //   compress these two 16-bit offsets into a 32-bit word
  static func createSource2(worldDimension: Float) -> String {
    // atoms.atoms
    // voxels
    // voxels.sparse.rebuiltVoxelIDs
    // voxels.sparse.memorySlots [32, 16]
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void rebuildProcess2(
        \(CrashBuffer.functionArguments),
        uint groupID [[threadgroup_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      groupshared uint threadgroupMemory[516];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
      )]
      void rebuildProcess2(
        uint groupID : SV_GroupID,
        uint localID : SV_GroupThreadID)
      """
      #endif
    }
    
    func allocateThreadgroupMemory() -> String {
      #if os(macOS)
      "threadgroup uint threadgroupMemory[516];"
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
  func rebuildProcess2(commandList: CommandList) {
    commandList.withPipelineState(shaders.rebuild.process2) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      let offset = GeneralCounters.offset(.rebuiltVoxelCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
  }
}
