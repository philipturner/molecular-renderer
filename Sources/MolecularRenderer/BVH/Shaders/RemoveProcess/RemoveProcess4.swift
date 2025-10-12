extension RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(memorySlotCount, 1, 1)
  // threadgroup memory 16 B
  //
  // scan for slots with no assigned voxel
  // create compact list of these slots (SIMD + group + global reduction)
  // write to sparse.vacantSlotIDs
  static func createSource4() -> String {
    func functionSignature() -> String {
      // TODO: Include memory slot count as a root 32-bit constant.
      #if os(macOS)
      """
      kernel void removeProcess4(
        \(CrashBuffer.functionArguments),
        uint globalID [[thread_position_in_grid]],
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
      void removeProcess4(
        uint globalID : SV_DispatchThreadID,
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
