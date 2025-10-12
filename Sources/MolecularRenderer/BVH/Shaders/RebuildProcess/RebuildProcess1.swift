extension RebuildProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // scan for rebuilt voxels
  // create a compact list of these voxels (SIMD + global reduction)
  // global counter is the indirect dispatch argument
  // write to sparse.rebuiltVoxelIDs
  //
  // read from dense.assignedSlotIDs
  //   do not use any optimizations to reduce the bandwidth cost
  // write to group.occupiedMarks
  //
  // createSource1
  static func createSource1(worldDimension: Float) -> String {
    // counters.general.rebuiltVoxelCount
    // voxels.group.rebuiltMarks
    // voxels.group.occupiedMarks
    // voxels.dense.assignedSlotIDs
    // voxels.sparse.rebuiltVoxelIDs
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void rebuildProcess1(
        \(CrashBuffer.functionArguments),
        uint3 globalID [[thread_position_in_grid]],
        uint3 groupID [[threadgroup_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
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
