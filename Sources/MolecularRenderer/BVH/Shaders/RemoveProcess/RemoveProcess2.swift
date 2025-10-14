extension RemoveProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // write to group.rebuiltMarks
  // scan for voxels with atoms removed
  // create compact list of these voxels (SIMD + global reduction)
  // global counter is the indirect dispatch argument
  // write to sparse.atomsRemovedVoxelCoords
  static func createSource2(worldDimension: Float) -> String {
    // counters.general.atomsRemovedVoxelCount
    // voxels.group.atomsRemovedMarks
    // voxels.group.rebuiltMarks
    // voxels.dense.atomsRemovedMarks
    // voxels.sparse.atomsRemovedVoxelCoords
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess2(
        \(CrashBuffer.functionArguments),
        device atomic_uint *atomsRemovedVoxelCount [[buffer(1)]],
        device uint *voxelGroupAtomsRemovedMarks [[buffer(2)]],
        device uint *voxelGroupRebuiltMarks [[buffer(3)]],
        device uchar *atomsRemovedMarks [[buffer(4)]],
        device uint *atomsRemovedVoxelCoords [[buffer(5)]],
        uint3 globalID [[thread_position_in_grid]],
        uint3 groupID [[threadgroup_position_in_grid]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> atomsRemovedVoxelCount : register(u1);
      RWStructuredBuffer<uint> voxelGroupAtomsRemovedMarks : register(u2);
      RWStructuredBuffer<uint> voxelGroupRebuiltMarks : register(u3);
      RWBuffer<uint> atomsRemovedMarks : register(u4);
      RWStructuredBuffer<uint> atomsRemovedVoxelCoords : register(u5);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "DescriptorTable(UAV(u4, numDescriptors = 1)),"
        "UAV(u5),"
      )]
      void removeProcess2(
        uint3 globalID : SV_DispatchThreadID,
        uint3 groupID : SV_GroupID)
      """
      #endif
    }
    
    func atomicFetchAdd() -> String {
      Reduction.atomicFetchAdd(
        buffer: "atomsRemovedVoxelCount",
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
      
      uint voxelGroupID =
      \(VoxelResources.generate("groupID", worldDimension / 8));
      uint voxelID =
      \(VoxelResources.generate("globalID", worldDimension / 2));
      
      if (voxelGroupAtomsRemovedMarks[voxelGroupID] == 0) {
        return;
      }
      voxelGroupRebuiltMarks[voxelGroupID] = 1;
      
      // scan for voxels with atoms removed
      bool hasAtomsRemoved = atomsRemovedMarks[voxelID];
      uint countBitsResult =
      \(Reduction.waveActiveCountBits("hasAtomsRemoved"));
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
      
      allocatedOffset += \(Reduction.wavePrefixSum("uint(hasAtomsRemoved)"));
      if (hasAtomsRemoved) {
        uint encoded = \(VoxelResources.encode("globalID"));
        atomsRemovedVoxelCoords[allocatedOffset] = encoded;
      }
    }
    """
  }
}

extension BVHBuilder {
  func removeProcess2(commandList: CommandList) {
    commandList.withPipelineState(shaders.remove.process2) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      commandList.setBuffer(
        counters.general,
        index: 1,
        offset: GeneralCounters.offset(.atomsRemovedVoxelCount))
      commandList.setBuffer(
        voxels.group.atomsRemovedMarks, index: 2)
      commandList.setBuffer(
        voxels.group.rebuiltMarks, index: 3)
      
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.atomsRemovedMarks, index: 4)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.atomsRemovedMarksHandleID, index: 4)
      #endif
      commandList.setBuffer(
        voxels.sparse.atomsRemovedVoxelCoords, index: 5)
      
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
