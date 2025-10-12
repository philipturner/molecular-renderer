extension RemoveProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // write to group.rebuiltMarks
  // scan for voxels with atoms removed
  // create compact list of these voxels (SIMD + global reduction)
  // global counter is the indirect dispatch argument
  // write to sparse.atomsRemovedVoxelIDs
  static func createSource2(worldDimension: Float) -> String {
    // counters.general.atomsRemovedVoxelCount
    // voxels.group.atomsRemovedMarks
    // voxels.group.rebuiltMarks
    // voxels.dense.atomsRemovedMarks
    // voxels.sparse.atomsRemovedVoxelIDs
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess2(
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
      void removeProcess2(
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
  func removeProcess2(commandList: CommandList) {
    commandList.withPipelineState(shaders.remove.process2) {
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
