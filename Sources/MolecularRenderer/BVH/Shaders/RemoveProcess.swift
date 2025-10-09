// First step: simply reset occupied marks to zero for all relevant atoms.
struct RemoveProcess {
  static func createSource1() -> String {
    func importStandardLibrary() -> String {
      #if os(macOS)
      """
      #include <metal_stdlib>
      using namespace metal;
      """
      #else
      ""
      #endif
    }
    
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess1(
        constant TransactionArgs &transactionArgs [[buffer(0)]],
        device uint *transactionIDs [[buffer(1)]],
        device float4 *transactionAtoms [[buffer(2)]],
        device uchar *occupied [[buffer(3)]],
        uint globalID [[thread_position_in_grid]])
      """
      #else
      """
      ConstantBuffer<TransactionArgs> transactionArgs : register(b0);
      RWStructuredBuffer<uint> transactionIDs : register(u1);
      RWStructuredBuffer<float4> transactionAtoms : register(u2);
      RWBuffer<uint> occupied : register(u3);
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        "RootConstants(b0, num32BitConstants = 3),"
        "UAV(u1),"
        "UAV(u2),"
        "DescriptorTable(UAV(u3, numDescriptors = 1)),"
      )]
      void removeProcess1(
        uint globalID : SV_DispatchThreadID)
      """
      #endif
    }
    
    // Check that the global ID falls within the removedIDs and not also
    // movedIDs, because this kernel will dispatch over moved as well.
    return """
    \(importStandardLibrary())
    
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
}
