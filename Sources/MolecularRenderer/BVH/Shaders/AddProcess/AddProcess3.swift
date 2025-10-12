extension AddProcess {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(movedCount + addedCount, 1, 1)
  // threadgroup memory 4096 B
  //
  // read atom from address space
  // restore the relativeOffsets
  // read from dense.atomicCounters
  //   add to relativeOffset, generating the correct offset
  // read from dense.assignedSlotIDs
  // write a 32-bit reference into sparse.memorySlots
  //
  // createSource3
  static func createSource3(worldDimension: Float) -> String {
    // atoms.*
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void addProcess3(
        \(CrashBuffer.functionArguments),
        \(AtomResources.functionArguments),
        uint globalID [[thread_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      \(AtomResources.functionArguments)
      groupshared uint cachedRelativeOffsets[8 * 128];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        \(AtomResources.rootSignatureArguments)
      )]
      void addProcess3(
        uint globalID : SV_DispatchThreadID,
        uint localID : SV_GroupThreadID)
      """
      #endif
    }
    
    func allocateThreadgroupMemory() -> String {
      #if os(macOS)
      "threadgroup uint cachedRelativeOffsets[8 * 128];"
      #else
      ""
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(pickPermutation())
    \(reorderForward())
    \(reorderBackward())
    \(TransactionArgs.shaderDeclaration)
    
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
  func addProcess3(
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    guard let transactionArgs else {
      fatalError("Transaction arguments were not set.")
    }
    
    commandList.withPipelineState(shaders.add.process3) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      atoms.setBufferBindings(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        transactionArgs: transactionArgs)
      
      // Determine the dispatch grid size.
      func createGroupCount32() -> SIMD3<UInt32> {
        var groupCount: Int = .zero
        groupCount += Int(transactionArgs.movedCount)
        groupCount += Int(transactionArgs.addedCount)
        
        let groupSize: Int = 128
        groupCount += groupSize - 1
        groupCount /= groupSize
        
        return SIMD3<UInt32>(
          UInt32(groupCount),
          UInt32(1),
          UInt32(1))
      }
      commandList.dispatch(groups: createGroupCount32())
    }
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
