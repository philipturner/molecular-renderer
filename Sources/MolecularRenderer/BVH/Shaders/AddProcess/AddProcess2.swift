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
  //
  // add existing atom count to prefix-summed 8 counters
  // write to dense.atomicCounters
  // if new atom count is too large, crash w/ diagnostic info
  // write new atom count into memory slot header
  //
  // createSource2
  static func createSource2(worldDimension: Float) -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void addProcess2(
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
