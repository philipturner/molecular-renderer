extension RebuildProcess {
  // [numthreads(4, 4, 4)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  //
  // scan for rebuilt voxels
  // create a compact list of these voxels (SIMD + global reduction)
  // global counter is the indirect dispatch argument
  // write to sparse.rebuiltVoxelCoords
  static func createSource1(worldDimension: Float) -> String {
    // counters.general.rebuiltVoxelCount
    // voxels.group.rebuiltMarks
    // voxels.group.rebuiltGroupCoords
    // voxels.dense.rebuiltMarks
    // voxels.sparse.rebuiltVoxelCoords
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void rebuildProcess1(
        \(CrashBuffer.functionArguments),
        device atomic_uint *rebuiltVoxelCount [[buffer(1)]],
        device uint *voxelGroupRebuiltMarks [[buffer(2)]],
        device uint *dispatchedGroupCoords [[buffer(3)]],
        device uchar *rebuiltMarks [[buffer(4)]],
        device uint *rebuiltVoxelCoords [[buffer(5)]],
        uint3 groupID [[threadgroup_position_in_grid]],
        uint3 localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> rebuiltVoxelCount : register(u1);
      RWStructuredBuffer<uint> voxelGroupRebuiltMarks : register(u2);
      RWStructuredBuffer<uint> dispatchedGroupCoords : register(u3);
      RWBuffer<uint> rebuiltMarks : register(u4);
      RWStructuredBuffer<uint> rebuiltVoxelCoords : register(u5);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "DescriptorTable(UAV(u4, numDescriptors = 1)),"
        "UAV(u5),"
      )]
      void rebuildProcess1(
        uint3 groupID : SV_GroupID,
        uint3 localID : SV_GroupThreadID)
      """
      #endif
    }
    
    func atomicFetchAdd() -> String {
      Reduction.atomicFetchAdd(
        buffer: "rebuiltVoxelCount",
        address: "0",
        operand: "countBitsResult",
        output: "allocatedOffset")
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      if (crashBuffer[0] != 1) {
        return;
      }
      
      \(DispatchVoxelGroups.setupKernel(worldDimension: worldDimension))
      
      if (voxelGroupRebuiltMarks[voxelGroupID] == 0) {
        return;
      }
      
      // scan for rebuilt voxels
      bool needsRebuild = rebuiltMarks[voxelID];
      uint countBitsResult =
      \(Reduction.waveActiveCountBits("needsRebuild"));
      if (countBitsResult == 0) {
        return;
      }
      
      // create a compact list of these voxels
      uint allocatedOffset = \(UInt32.max);
      if (\(Reduction.waveIsFirstLane())) {
        \(atomicFetchAdd())
      }
      allocatedOffset =
      \(Reduction.waveReadLaneAt("allocatedOffset", laneID: 0));
      
      allocatedOffset += \(Reduction.wavePrefixSum("uint(needsRebuild)"));
      if (needsRebuild) {
        uint encoded = \(VoxelResources.encode("voxelCoords"));
        rebuiltVoxelCoords[allocatedOffset] = encoded;
      }
    }
    """
  }
}

extension BVHBuilder {
  func rebuildProcess1(commandList: CommandList) {
    commandList.withPipelineState(shaders.rebuild.process1) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      commandList.setBuffer(
        counters.general,
        index: 1,
        offset: GeneralCounters.offset(.rebuiltVoxelCount))
      commandList.setBuffer(
        voxels.group.rebuiltMarks, index: 2)
      commandList.setBuffer(
        voxels.group.rebuiltGroupCoords, index: 3)
      
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.rebuiltMarks, index: 4)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.rebuiltMarksHandleID, index: 4)
      #endif
      commandList.setBuffer(
        voxels.sparse.rebuiltVoxelCoords, index: 5)
      
      let offset = GeneralCounters.offset(.rebuiltGroupCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
