// First step: update the positions and motion vectors in the address space
// in the first kernel
struct AddProcess {
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
      kernel void addProcess1(
        constant TransactionArgs &transactionArgs [[buffer(0)]],
        device uint *transactionIDs [[buffer(1)]],
        device float4 *transactionAtoms [[buffer(2)]],
        device float4 *atoms [[buffer(3)]],
        device half4 *motionVectors [[buffer(4)]],
        device uchar *occupied [[buffer(5)]],
        device ushort4 *relativeOffsets1 [[buffer(6)]],
        device ushort4 *relativeOffsets2 [[buffer(7)]],
        device uint *voxelGroupMarks [[buffer(8)]],
        device atomic_uint *atomicCounters [[buffer(9)]],
        uint globalID [[thread_position_in_grid]])
      """
      #else
      
      #endif
    }
    
    return """
    \(importStandardLibrary())
    
    \(AtomStyles.createAtomRadii(AtomStyles.radii))
    \(TransactionArgs.shaderDeclaration)
    
    \(functionSignature())
    {
      
    }
    """
  }
}
