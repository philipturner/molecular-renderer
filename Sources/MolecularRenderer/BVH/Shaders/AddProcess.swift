// First step: update the positions and motion vectors in the address space
// in the first kernel
struct AddProcess {
  static func createSource1() -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void addProcess1(
        \(AtomResources.functionArguments),
        device uint *voxelGroupMarks [[buffer(8)]],
        device atomic_uint *atomicCounters [[buffer(9)]],
        uint globalID [[thread_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(AtomResources.functionArguments)
      RWStructuredBuffer<uint> voxelGroupMarks : register(u8);
      RWStructuredBuffer<uint> atomicCounters : register(u9);
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(AtomResources.rootSignatureArguments)
        "UAV(u8),"
        "UAV(u9),"
      )]
      void addProcess1(
        uint globalID : SV_DispatchThreadID,
        uint localID : SV_GroupThreadID)
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
    
    \(AtomStyles.createAtomRadii(AtomStyles.radii))
    \(TransactionArgs.shaderDeclaration)
    
    \(functionSignature())
    {
      uint removedCount = transactionArgs.removedCount;
      uint movedCount = transactionArgs.movedCount;
      uint addedCount = transactionArgs.addedCount;
      if (globalID >= movedCount + addedCount) {
        return;
      }
      
      uint atomID = transactionIDs[removedCount + globalID];
      float4 atom = transactionAtoms[removedCount + globalID];
      occupied[atomID] = 1;
      
      float4 motionVector = 0;
      if (globalID < movedCount) {
        float4 previousAtom = atoms[atomID];
        motionVector = previousAtom - atom;
      }
      atoms[atomID] = atom;
      \(writeMotionVector())
    }
    """
  }
}
