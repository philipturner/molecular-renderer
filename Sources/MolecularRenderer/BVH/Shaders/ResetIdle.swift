// First step: implement the motion vectors resetting kernel
struct ResetIdle {
  static func resetMotionVectors() -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void resetMotionVectors(
        \(AtomResources.functionArguments),
        uint globalID [[thread_position_in_grid]])
      """
      #else
      """
      \(AtomResources.functionArguments)
      
      [numthreads(128, 1, 1)]
      [RootSignature(
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
        device uint *voxelGroupMarks [[buffer(0)]],
        device uint4 *atomicCounters [[buffer(1)]],
        uint3 globalID [[thread_position_in_grid]],
        uint3 groupID [[threadgroup_position_in_grid]])
      """
      #else
      """
      RWStructuredBuffer<uint> voxelGroupMarks : register(u0);
      RWStructuredBuffer<uint4> atomicCounters : register(u1);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        "UAV(u0),"
        "UAV(u1),"
      )]
      void resetAtomicCounters(
        uint3 globalID : SV_DispatchThreadID,
        uint3 groupID : SV_GroupThreadID)
      """
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      // Read the voxel group mark.
      uint mark;
      {
        uint address =
        \(VoxelResources.generate("groupID", worldDimension / 8));
        mark = voxelGroupMarks[address];
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
        voxelResources.voxelGroupMarks, index: 0)
      commandList.setBuffer(
        voxelResources.atomicCounters, index: 1)
      
      let worldDimension = voxelResources.worldDimension
      let voxelGroupCount = VoxelResources.voxelGroupCount(
        worldDimension: worldDimension)
      let groups = SIMD3<UInt32>(repeating: UInt32(voxelGroupCount))
      commandList.dispatch(groups: groups)
    }
  }
}
