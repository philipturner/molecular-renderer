// First step: implement the motion vectors resetting kernel
struct ResetIdle {
  static func resetMotionVectors() -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void resetMotionVectors(
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
      void resetMotionVectors(
        uint globalID : SV_DispatchThreadID)
      """
      #endif
    }
    
    func writeMotionVector() -> String {
      #if os(macOS)
      "motionVectors[atomID] = half4(motionVector);"
      #else
      "motionVectors[atomID] = motionVector;"
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(TransactionArgs.shaderDeclaration)
    
    \(functionSignature())
    {
      uint removedCount = transactionArgs.removedCount;
      uint movedCount = transactionArgs.movedCount;
      if (globalID >= movedCount) {
        return;
      }
      
      uint atomID = transactionIDs[removedCount + globalID];
      float4 motionVector = 0;
      \(writeMotionVector())
    }
    """
  }
}
