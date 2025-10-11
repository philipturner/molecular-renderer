struct RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(removedCount + movedCount, 1, 1)
  //
  // reset the occupiedMark of each atom
  //   0 if removed
  //   2 if moved
  // write to group.atomsRemovedMarks
  // write to dense.atomsRemovedMarks
  static func createSource1() -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess1(
        \(CrashBuffer.functionArguments),
        \(AtomResources.functionArguments),
        uint globalID [[thread_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      \(AtomResources.functionArguments)
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        \(AtomResources.rootSignatureArguments)
      )]
      void removeProcess1(
        uint globalID : SV_DispatchThreadID)
      """
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(TransactionArgs.shaderDeclaration)
    
    \(functionSignature())
    {
      if (crashBuffer[0] != 1) {
        return;
      }
      
      uint removedCount = transactionArgs.removedCount;
      uint movedCount = transactionArgs.movedCount;
      if (globalID >= removedCount + movedCount) {
        return;
      }
      
      uint atomID = transactionIDs[globalID];
      addressOccupiedMarks[atomID] = 0;
    }
    """
  }
  
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // scan for voxels with atoms removed
  // write to group.rebuiltMarks
  // create compact list of these voxels (SIMD reduction, then global atomic)
  // prepare the indirect dispatch for the next kernel
  // createSource2
  
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  //
  // check the occupiedMark of each atom in voxel
  //   if either 0 or 2, remove from the list
  // prefix sum to compact the reference list (threadgroup-wide reduction)
  // update the global -> 2 nm offset of surviving atoms
  //
  // if atoms remain, write to dense.rebuiltMarks
  // otherwise, reset entry in dense.assignedSlotIDs and sparse.assignedVoxelIDs
  // createSource3
  
  // [numthreads(128, 1, 1)]
  
  // scan for slots with no assigned voxel
  // create compact list of these slots
  // createSource4
}

extension BVHBuilder {
  func removeProcess1(
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    guard let transactionArgs else {
      fatalError("Transaction arguments were not set.")
    }
    
    commandList.withPipelineState(shaders.removeProcess1) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      atomResources.setBufferBindings(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        transactionArgs: transactionArgs)
      
      // Determine the dispatch grid size.
      func createGroupCount32() -> SIMD3<UInt32> {
        var groupCount: Int = .zero
        groupCount += Int(transactionArgs.removedCount)
        groupCount += Int(transactionArgs.movedCount)
        
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
