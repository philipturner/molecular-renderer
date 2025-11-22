struct ResetIdle {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(movedCount, 1, 1)
  static func resetMotionVectors(
    supports16BitTypes: Bool
  ) -> String {
    // atoms.*
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void resetMotionVectors(
        \(CrashBuffer.functionArguments),
        \(AtomResources.functionArguments(supports16BitTypes)),
        uint globalID [[thread_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      \(AtomResources.functionArguments(supports16BitTypes))
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        \(AtomResources.rootSignatureArguments(supports16BitTypes))
      )]
      void resetMotionVectors(
        uint globalID : SV_DispatchThreadID)
      """
      #endif
    }

    func castHalf4(_ input: String) -> String {
      if supports16BitTypes {
        return "half4(\(input))"
      } else {
        return input
      }
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
      motionVectors[atomID] = \(castHalf4("motionVector"));
    }
    """
  }
  
  // [numthreads(4, 4, 4)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  static func resetVoxelMarks(worldDimension: Float) -> String {
    // voxels.group.atomsRemovedMarks
    // voxels.group.addedMarks
    // voxels.group.rebuiltMarks
    // voxels.group.resetGroupCoords
    // voxels.dense.atomsRemovedMarks
    // voxels.dense.atomicCounters
    // voxels.dense.rebuiltMarks
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void resetVoxelMarks(
        \(CrashBuffer.functionArguments),
        device uint *voxelGroupAtomsRemovedMarks [[buffer(1)]],
        device uint *voxelGroupAddedMarks [[buffer(2)]],
        device uint *voxelGroupRebuiltMarks [[buffer(3)]],
        device uint *dispatchedGroupCoords [[buffer(4)]],
        device uchar *atomsRemovedMarks [[buffer(5)]],
        device uint4 *atomicCounters [[buffer(6)]],
        device uchar *rebuiltMarks [[buffer(7)]],
        uint3 groupID [[threadgroup_position_in_grid]],
        uint3 localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> voxelGroupAtomsRemovedMarks : register(u1);
      RWStructuredBuffer<uint> voxelGroupAddedMarks : register(u2);
      RWStructuredBuffer<uint> voxelGroupRebuiltMarks : register(u3);
      RWStructuredBuffer<uint> dispatchedGroupCoords : register(u4);
      RWBuffer<uint> atomsRemovedMarks : register(u5);
      RWStructuredBuffer<uint4> atomicCounters : register(u6);
      RWBuffer<uint> rebuiltMarks : register(u7);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
        "DescriptorTable(UAV(u5, numDescriptors = 1)),"
        "UAV(u6),"
        "DescriptorTable(UAV(u7, numDescriptors = 1)),"
      )]
      void resetVoxelMarks(
        uint3 groupID : SV_GroupID,
        uint3 localID : SV_GroupThreadID)
      """
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      if (crashBuffer[0] != 1) {
        return;
      }
      
      \(DispatchVoxelGroups.setupKernel(worldDimension: worldDimension))
      
      if (voxelGroupAtomsRemovedMarks[voxelGroupID]) {
        atomsRemovedMarks[voxelID] = 0;
      }
      
      if (voxelGroupAddedMarks[voxelGroupID]) {
        atomicCounters[2 * voxelID + 0] = 0;
        atomicCounters[2 * voxelID + 1] = 0;
      }
      
      if (voxelGroupRebuiltMarks[voxelGroupID]) {
        rebuiltMarks[voxelID] = 0;
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
      atoms.setBufferBindings(
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
  
  func resetVoxelMarks(
    commandList: CommandList
  ) {
    commandList.withPipelineState(shaders.resetVoxelMarks) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
        
      // Bind the group buffers.
      commandList.setBuffer(
        voxels.group.atomsRemovedMarks, index: 1)
      commandList.setBuffer(
        voxels.group.addedMarks, index: 2)
      commandList.setBuffer(
        voxels.group.rebuiltMarks, index: 3)
      commandList.setBuffer(
        voxels.group.resetGroupCoords, index: 4)
      
      // Bind the dense buffers.
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.atomsRemovedMarks, index: 5)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.atomsRemovedMarksHandleID, index: 5)
      #endif
      commandList.setBuffer(
        voxels.dense.atomicCounters, index: 6)
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.rebuiltMarks, index: 7)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.rebuiltMarksHandleID, index: 7)
      #endif
      
      let offset = GeneralCounters.offset(.resetGroupCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
  }
}
