// Send data back to CPU through the crash buffer.
struct DebugDiagnostic {
  static func createSource() -> String {
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
      
      [numthreads(128, 1, 1)]
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
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      if (globalID >= 50000 * 2) {
        return;
      }
      
      crashBuffer[globalID] = dataBuffer[globalID];
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
        counters.crashBuffer.nativeBuffer, index: 1)
      
      // Determine the dispatch grid size.
      func createGroupCount32() -> SIMD3<UInt32> {
        var groupCount: Int = 50000 * 2
        
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
  }
}
