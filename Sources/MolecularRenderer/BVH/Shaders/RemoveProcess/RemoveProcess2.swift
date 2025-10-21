extension RemoveProcess {
  // [numthreads(4, 4, 4)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
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
    // voxels.group.atomsRemovedGroupCoords
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
        device uint *dispatchedGroupCoords [[buffer(4)]],
        device uchar *atomsRemovedMarks [[buffer(5)]],
        device uint *atomsRemovedVoxelCoords [[buffer(6)]],
        uint3 groupID [[threadgroup_position_in_grid]],
        uint3 localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<uint> atomsRemovedVoxelCount : register(u1);
      RWStructuredBuffer<uint> voxelGroupAtomsRemovedMarks : register(u2);
      RWStructuredBuffer<uint> voxelGroupRebuiltMarks : register(u3);
      RWStructuredBuffer<uint> dispatchedGroupCoords : register(u4);
      RWBuffer<uint> atomsRemovedMarks : register(u5);
      RWStructuredBuffer<uint> atomsRemovedVoxelCoords : register(u6);
      
      [numthreads(4, 4, 4)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
        "DescriptorTable(UAV(u5, numDescriptors = 1)),"
        "UAV(u6),"
      )]
      void removeProcess2(
        uint3 groupID : SV_GroupID,
        uint3 localID : SV_GroupThreadID)
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
      
      \(DispatchVoxelGroups.setupKernel(worldDimension: worldDimension))
      
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
        uint encoded = \(VoxelResources.encode("voxelCoords"));
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
      commandList.setBuffer(
        voxels.group.atomsRemovedGroupCoords, index: 4)
      
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.atomsRemovedMarks, index: 5)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.atomsRemovedMarksHandleID, index: 5)
      #endif
      commandList.setBuffer(
        voxels.sparse.atomsRemovedVoxelCoords, index: 6)
      
      let offset = GeneralCounters.offset(.atomsRemovedGroupCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
