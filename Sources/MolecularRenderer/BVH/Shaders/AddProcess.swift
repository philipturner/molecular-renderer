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
        uint globalID [[thread_position_in_grid]])
      """
      #else
      """
      \(AtomResources.functionArguments)
      RWStructuredBuffer<uint> voxelGroupMarks : register(u8);
      RWStructuredBuffer<uint> atomicCounters : register(u9);
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(AtomResources.rootSignatureArguments)
      )]
      """
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(AtomStyles.createAtomRadii(AtomStyles.radii))
    \(TransactionArgs.shaderDeclaration)
    
    \(functionSignature())
    {
      
    }
    """
  }
}
