struct ResetIdle {
  static func resetMotionVectors() -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void resetMotionVectors(
        \(CrashBuffer.functionArguments),
        \(AtomResources.functionArguments),
        uint globalID [[thread_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      \(AtomResources.functionArguments)
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
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
      if (crashBuffer[0] != 1) {
        return;
      }
      
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
  
  static func resetAtomicCounters(worldDimension: Float) -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void resetAtomicCounters(
        device uint *voxelGroupAddedMarks [[buffer(0)]],
        device uint4 *atomicCounters [[buffer(1)]],
        uint3 globalID [[thread_position_in_grid]],
        uint3 groupID [[threadgroup_position_in_grid]])
      """
      #else
      """
      RWStructuredBuffer<uint> voxelGroupAddedMarks : register(u0);
      RWStructuredBuffer<uint4> atomicCounters : register(u1);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        "UAV(u0),"
        "UAV(u1),"
      )]
      void resetAtomicCounters(
        uint3 globalID : SV_DispatchThreadID,
        uint3 groupID : SV_GroupID)
      """
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      // Read the voxel group added mark.
      uint mark;
      {
        uint address =
        \(VoxelResources.generate("groupID", worldDimension / 8));
        mark = voxelGroupAddedMarks[address];
      }
      
      // Return early if the voxel is empty.
      if (mark == 0) {
        return;
      }
      
      // Reset the atomic counter.
      {
        uint address =
        \(VoxelResources.generate("globalID", worldDimension / 2));
        atomicCounters[2 * address + 0] = 0;
        atomicCounters[2 * address + 1] = 0;
      }
    }
    """
  }
}

extension BVHBuilder {
  func resetMotionVectors(
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    guard let transactionArgs else {
      fatalError("Transaction arguments were not set.")
    }
    
    commandList.withPipelineState(shaders.resetMotionVectors) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      atomResources.setBufferBindings(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        transactionArgs: transactionArgs)
      
      // Determine the dispatch grid size.
      func createGroupCount32() -> SIMD3<UInt32> {
        var groupCount: Int = .zero
        groupCount += Int(transactionArgs.movedCount)
        
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
  
  func resetAtomicCounters(
    commandList: CommandList
  ) {
    commandList.withPipelineState(shaders.resetAtomicCounters) {
      commandList.setBuffer(
        voxelResources.voxelGroupAddedMarks, index: 0)
      commandList.setBuffer(
        voxelResources.atomicCounters, index: 1)
      
      let worldDimension = voxelResources.worldDimension
      let gridSize = Int(worldDimension / 8)
      let threadgroupCount = SIMD3<UInt32>(
        UInt32(gridSize),
        UInt32(gridSize),
        UInt32(gridSize))
      commandList.dispatch(groups: threadgroupCount)
    }
  }
}
