// First step: simply reset occupied marks to zero for all relevant atoms.
struct RemoveProcess {
  static func createSource1() -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess1(
        \(AtomResources.functionArguments),
        uint globalID [[thread_position_in_grid]])
      """
      #else
      """
      \(AtomResources.functionArguments)
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(AtomResources.rootSignatureArguments)
      )]
      void removeProcess1(
        uint globalID : SV_DispatchThreadID)
      """
      #endif
    }
    
    // Check that the global ID falls within the removedIDs and not also
    // movedIDs, because this kernel will dispatch over moved as well.
    return """
    \(Shader.importStandardLibrary)
    
    \(TransactionArgs.shaderDeclaration)
    
    \(functionSignature())
    {
      uint removedCount = transactionArgs.removedCount;
      uint movedCount = transactionArgs.movedCount;
      if (globalID >= removedCount + movedCount) {
        return;
      }
      
      uint atomID = transactionIDs[globalID];
      occupied[atomID] = 0;
    }
    """
  }
}

extension BVHBuilder {
  func removeProcess1(
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    // TODO: Enable encoding again once arguments are fixed
    #if false
    guard let transactionArgs else {
      fatalError("Transaction arguments were not set.")
    }
      
    commandList.withPipelineState(shaders.removeProcess1) {
      // Bind the transaction arguments.
      commandList.set32BitConstants(transactionArgs, index: 0)
      
      // Bind the transaction buffers.
      let idsBuffer = atomResources.transactionIDs
        .nativeBuffers[inFlightFrameID]
      let atomsBuffer = atomResources.transactionAtoms
        .nativeBuffers[inFlightFrameID]
      commandList.setBuffer(idsBuffer, index: 1)
      commandList.setBuffer(atomsBuffer, index: 2)
      
      // Bind the occupied marks.
      #if os(macOS)
      commandList.setBuffer(
        atomResources.occupied, index: 3)
      #else
      commandList.setDescriptor(
        handleID: atomResources.occupiedHandleID,
        index: 3)
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
  #endif
}
