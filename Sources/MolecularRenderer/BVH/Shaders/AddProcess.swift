// First step: update the positions and motion vectors in the address space
// in the first kernel
struct AddProcess {
  static func createSource1() -> String {
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
      """
      ConstantBuffer<TransactionArgs> transactionArgs : register(b0);
      RWStructuredBuffer<uint> transactionIDs : register(u1);
      RWStructuredBuffer<float4> transactionAtoms : register(u2);
      RWStructuredBuffer<float4> atoms : register(u3);
      RWBuffer<float4> motionVectors : register(u4);
      RWBuffer<uint> occupied : register(u5);
      RWBuffer<uint4> relativeOffsets1 : register(u6);
      RWBuffer<uint4> relativeOffsets2 : register(u7);
      RWStructuredBuffer<uint> voxelGroupMarks : register(u8);
      RWStructuredBuffer<uint> atomicCounters : register(u9);
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        "RootConstants(b0, num32BitConstants = 3),"
        "UAV(u1),"
        "UAV(u2),"
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
