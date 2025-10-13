extension RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(removedCount + movedCount, 1, 1)
  //
  // read atom from address space
  // reset the addressOccupiedMark
  //   0 if removed
  //   2 if moved
  // write to group.atomsRemovedMarks
  // write to dense.atomsRemovedMarks
  static func createSource1(worldDimension: Float) -> String {
    // atoms.*
    // voxels.group.atomsRemovedMarks
    // voxels.dense.atomsRemovedMarks
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess1(
        \(CrashBuffer.functionArguments),
        \(AtomResources.functionArguments),
        device uint *voxelGroupAtomsRemovedMarks [[buffer(9)]],
        device uchar *atomsRemovedMarks [[buffer(10)]],
        uint globalID [[thread_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      \(AtomResources.functionArguments)
      RWStructuredBuffer<uint> voxelGroupAtomsRemovedMarks : register(u9);
      RWBuffer<uint> atomsRemovedMarks : register(u10);
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        \(AtomResources.rootSignatureArguments)
        "UAV(u9),"
        "DescriptorTable(UAV(u10, numDescriptors = 1)),"
      )]
      void removeProcess1(
        uint globalID : SV_DispatchThreadID)
      """
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(AddProcess.pickPermutation())
    \(AddProcess.reorderForward())
    \(AddProcess.reorderBackward())
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
}

extension BVHBuilder {
  func removeProcess1(
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    guard let transactionArgs else {
      fatalError("Transaction arguments were not set.")
    }
    
    commandList.withPipelineState(shaders.remove.process1) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      atoms.setBufferBindings(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        transactionArgs: transactionArgs)
      commandList.setBuffer(
        voxels.group.atomsRemovedMarks, index: 9)
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.atomsRemovedMarks, index: 10)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.atomsRemovedMarksHandleID, index: 10)
      #endif
      
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
