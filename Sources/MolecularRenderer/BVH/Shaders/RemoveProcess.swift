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
      
      if (globalID < removedCount) {
        occupied[atomID] = 0;
      }
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
      commandList.set32BitConstants(
        transactionArgs, index: 0)
      
      // Bind the transaction buffers.
      let idsBuffer = atomResources.transactionIDs
        .nativeBuffers[inFlightFrameID]
      let atomsBuffer = atomResources.transactionAtoms
        .nativeBuffers[inFlightFrameID]
    }
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
