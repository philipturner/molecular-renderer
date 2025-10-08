// Send data back to CPU through the crash buffer.
struct ClearBufferShader {
  static func createSource() -> String {
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
    
    func constantArgs() -> String {
      """
      struct ConstantArgs {
        uint elementCount; // TODO: Return early if out of bounds.
        uint clearValue;
      };
      """
    }
    
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void clearBuffer(
        constant ConstantArgs &constantArgs [[buffer(0)]],
        device uint *clearedBuffer [[buffer(1)]],
        uint threadID [[thread_position_in_grid]])
      """
      #else
      """
      ConstantBuffer<ConstantArgs> constantArgs : register(b0);
      RWStructuredBuffer<uint> clearedBuffer : register(u1);
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        "RootConstants(b0, num32BitConstants = 2),"
        "UAV(u1),"
      )]
      void clearBuffer(
        uint threadID : SV_DispatchThreadID)
      """
      #endif
    }
    
    return """
    \(importStandardLibrary())
    
    \(constantArgs())
    
    \(functionSignature())
    {
      if (tid >= constantArgs.elementCount) {
        return;
      }
      
      clearedBuffer[tid] = constantArgs.clearValue;
    }
    """
  }
}
