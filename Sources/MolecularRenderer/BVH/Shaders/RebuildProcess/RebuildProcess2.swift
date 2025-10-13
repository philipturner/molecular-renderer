extension RebuildProcess {
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  // threadgroup memory 2064 B
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
    // voxels.dense.assignedSlotIDs
    // voxels.sparse.rebuiltVoxelCoords
    // voxels.sparse.memorySlots [32, 16]
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void rebuildProcess2(
        \(CrashBuffer.functionArguments),
        device float4 *atoms [[buffer(1)]],
        device uint *assignedSlotIDs [[buffer(2)]],
        device uint *rebuiltVoxelCoords [[buffer(3)]],
        device uint *memorySlots32 [[buffer(4)]],
        device ushort *memorySlots16 [[buffer(5)]],
        uint groupID [[threadgroup_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<float4> atoms : register(u1);
      RWStructuredBuffer<uint> assignedSlotIDs : register(u2);
      RWStructuredBuffer<uint> rebuiltVoxelCoords : register(u3);
      RWStructuredBuffer<uint> memorySlots32 : register(u4);
      RWBuffer<uint> memorySlots16 : register(u5);
      groupshared uint threadgroupMemory[516];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
        "DescriptorTable(UAV(u5, numDescriptors = 1)),"
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
      
      // Use arithmetic utility function to encode/decode RGB10 instead of
      // relying on hardware data unpacking.
    }
    """
  }
}

extension BVHBuilder {
  func rebuildProcess2(commandList: CommandList) {
    commandList.withPipelineState(shaders.rebuild.process2) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      commandList.setBuffer(
        atoms.atoms, index: 1)
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 2)
      commandList.setBuffer(
        voxels.sparse.rebuiltVoxelCoords, index: 3)
      commandList.setBuffer(
        voxels.sparse.memorySlots, index: 4)
      #if os(macOS)
      commandList.setBuffer(
        voxels.sparse.memorySlots, index: 5)
      #else
      commandList.setDescriptor(
        handleID: voxels.sparse.memorySlotsHandleID, index: 5)
      #endif
      
      let offset = GeneralCounters.offset(.rebuiltVoxelCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
  }
}
