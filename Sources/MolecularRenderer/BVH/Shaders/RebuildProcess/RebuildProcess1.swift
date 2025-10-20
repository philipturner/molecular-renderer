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
    // voxels.group.occupiedMarks
    // voxels.group.rebuiltGroupCoords [TODO]
    // voxels.dense.assignedSlotIDs
    // voxels.dense.rebuiltMarks
    // voxels.sparse.rebuiltVoxelCoords
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void rebuildProcess1(
        \(CrashBuffer.functionArguments),
        device atomic_uint *rebuiltVoxelCount [[buffer(1)]],
        device uint *voxelGroupRebuiltMarks [[buffer(2)]],
        device uint *voxelGroup8OccupiedMarks [[buffer(3)]],
        device uint *voxelGroup32OccupiedMarks [[buffer(4)]],
        device uint *assignedSlotIDs [[buffer(5)]],
        device uchar *rebuiltMarks [[buffer(6)]],
        device uint *rebuiltVoxelCoords [[buffer(7)]],
        uint3 groupID [[threadgroup_position_in_grid]],
        uint3 localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> rebuiltVoxelCount : register(u1);
      RWStructuredBuffer<uint> voxelGroupRebuiltMarks : register(u2);
      RWStructuredBuffer<uint> voxelGroup8OccupiedMarks : register(u3);
      RWStructuredBuffer<uint> voxelGroup32OccupiedMarks : register(u4);
      RWStructuredBuffer<uint> assignedSlotIDs : register(u5);
      RWBuffer<uint> rebuiltMarks : register(u6);
      RWStructuredBuffer<uint> rebuiltVoxelCoords : register(u7);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
        "UAV(u5),"
        "DescriptorTable(UAV(u6, numDescriptors = 1)),"
        "UAV(u7),"
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
      // TODO: When the kernel is migrated, do not check the crash buffer.
      if (crashBuffer[0] != 1) {
        return;
      }
      
      \(DispatchVoxelGroups.setupKernel(worldDimension: worldDimension))
      
      // read from dense.assignedSlotIDs
      uint slotID = assignedSlotIDs[voxelID];
      if (slotID != \(UInt32.max)) {
        // TODO: When the kernel is migrated, avoid computation of the
        // voxel group ID until absolutely necessary.
        voxelGroup8OccupiedMarks[voxelGroup8ID] = 1;
        
        uint3 voxelGroup32Coords = groupID / 4;
        uint voxelGroup32ID =
        \(VoxelResources.generate("voxelGroup32Coords", worldDimension / 32));
        voxelGroup32OccupiedMarks[voxelGroup32ID] = 1;
      }
      
      if (voxelGroupRebuiltMarks[voxelGroup8ID] == 0) {
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
        uint encoded = \(VoxelResources.encode("globalID"));
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
        voxels.group.occupiedMarks8, index: 3)
      commandList.setBuffer(
        voxels.group.occupiedMarks32, index: 4)
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 5)
      
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.rebuiltMarks, index: 6)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.rebuiltMarksHandleID, index: 6)
      #endif
      commandList.setBuffer(
        voxels.sparse.rebuiltVoxelCoords, index: 7)
      
      let gridSize = Int(voxels.worldDimension / 8)
      let threadgroupCount = SIMD3<UInt32>(
        UInt32(gridSize),
        UInt32(gridSize),
        UInt32(gridSize))
      commandList.dispatch(groups: threadgroupCount)
    }
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
