// Clear a buffer of UInt32 to a repeating scalar value.
struct ClearBuffer {
  static func createSource() -> String {
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
    \(Shader.importStandardLibrary)
    
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

extension BVHBuilder {
  func clearBuffer(
    commandList: CommandList,
    elementCount: Int,
    clearValue: UInt32,
    clearedBuffer: Buffer
  ) {
    commandList.withPipelineState(shaders.clearBuffer) {
      // Bind the constant arguments.
      struct ConstantArgs {
        var elementCount: UInt32 = .zero
        var clearValue: UInt32 = .zero
      }
      var constantArgs = ConstantArgs()
      constantArgs.elementCount = UInt32(elementCount)
      constantArgs.clearValue = clearValue
      commandList.set32BitConstants(
        constantArgs, index: 0)
      
      // Bind the cleared buffer.
      commandList.setBuffer(
        clearedBuffer, index: 1)
      
      // Determine the dispatch grid size.
      func createGroupCount32() -> SIMD3<UInt32> {
        var groupCount: Int = elementCount
        
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
