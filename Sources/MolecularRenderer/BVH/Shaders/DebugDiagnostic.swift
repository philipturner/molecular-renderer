// Send data back to CPU through the crash buffer.
struct DebugDiagnostic {
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
    
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void debugDiagnostic(
        device uint *dataBuffer [[buffer(0)]],
        device uint *crashBuffer [[buffer(1)]],
        uint globalID [[thread_position_in_grid]])
      """
      #else
      """
      RWStructuredBuffer<uint> dataBuffer : register(u0);
      RWStructuredBuffer<uint> crashBuffer : register(u1);
      
      [numthreads(1, 1, 1)]
      [RootSignature(
        "UAV(u0),"
        "UAV(u1),"
      )]
      void debugDiagnostic(
        uint globalID : SV_DispatchThreadID)
      """
      #endif
    }
    
    return """
    \(importStandardLibrary())
    
    \(functionSignature())
    {
      
    }
    """
  }
}

extension BVHBuilder {
  func debugDiagnostic(
    commandList: CommandList,
    dataBuffer: Buffer
  ) {
    commandList.withPipelineState(shaders.debugDiagnostic) {
      // Bind the data buffer.
      commandList.setBuffer(
        dataBuffer, index: 0)
      
      // Bind the crash buffer.
      commandList.setBuffer(
        crashBuffer.nativeBuffer, index: 1)
      
      
    }
  }
}
