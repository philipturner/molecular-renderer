// Clear a buffer of UInt32 to a repeating scalar value.
struct ClearBuffer {
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
        uint elementCount;
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
        uint globalID [[thread_position_in_grid]])
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
        uint globalID : SV_DispatchThreadID)
      """
      #endif
    }
    
    return """
    \(importStandardLibrary())
    
    \(constantArgs())
    
    \(functionSignature())
    {
      if (globalID >= constantArgs.elementCount) {
        return;
      }
      
      clearedBuffer[globalID] = constantArgs.clearValue;
    }
    """
  }
}
