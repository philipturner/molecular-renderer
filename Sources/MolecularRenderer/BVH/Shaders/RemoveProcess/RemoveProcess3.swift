extension RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  // threadgroup memory 20 B
  //
  // check the addressOccupiedMark of each atom in voxel
  //   if either 0 or 2, remove from the list
  // prefix sum to compact the reference list (SIMD + group reduction)
  // write to sparse.memorySlots in-place, sanitized to 128 atoms at a time
  // write new atom count into memory slot header
  //
  // if atoms remain, write to dense.rebuiltMarks
  // otherwise
  //   reset entry in dense.assignedSlotIDs and sparse.assignedVoxelCoords
  static func createSource3(
    memorySlotCount: Int,
    worldDimension: Float
  ) -> String {
    // atoms.addressOccupiedMarks
    // voxels.dense.assignedSlotIDs
    // voxels.dense.rebuiltMarks
    // voxels.sparse.assignedVoxelCoords
    // voxels.sparse.atomsRemovedVoxelCoords
    // voxels.sparse.memorySlots.headerLarge
    // voxels.sparse.memorySlots.referenceLarge
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess3(
        \(CrashBuffer.functionArguments),
        device uchar *addressOccupiedMarks [[buffer(1)]],
        device uint *assignedSlotIDs [[buffer(2)]],
        device uchar *rebuiltMarks [[buffer(3)]],
        device uint *assignedVoxelCoords [[buffer(4)]],
        device uint *atomsRemovedVoxelCoords [[buffer(5)]],
        device uint *headers [[buffer(6)]],
        device uint *references32 [[buffer(7)]],
        uint groupID [[threadgroup_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      RWBuffer<uint> addressOccupiedMarks : register(u1);
      RWStructuredBuffer<uint> assignedSlotIDs : register(u2);
      RWBuffer<uint> rebuiltMarks : register(u3);
      RWStructuredBuffer<uint> assignedVoxelCoords : register(u4);
      RWStructuredBuffer<uint> atomsRemovedVoxelCoords : register(u5);
      RWStructuredBuffer<uint> headers : register(u6);
      RWStructuredBuffer<uint> references32 : register(u7);
      groupshared uint threadgroupMemory[5];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "DescriptorTable(UAV(u1, numDescriptors = 1)),"
        "UAV(u2),"
        "DescriptorTable(UAV(u3, numDescriptors = 1)),"
        "UAV(u4),"
        "UAV(u5),"
        "UAV(u6),"
        "UAV(u7),"
      )]
      void removeProcess3(
        uint groupID : SV_GroupID,
        uint localID : SV_GroupThreadID)
      """
      #endif
    }
    
    func allocateThreadgroupMemory() -> String {
      #if os(macOS)
      "threadgroup uint threadgroupMemory[5];"
      #else
      ""
      #endif
    }

    func waveID() -> String {
      "localID / \(Reduction.waveGetLaneCount())"
    }
    
    func initializeAddress32() -> String {
      let overflows32 = SparseVoxelResources.overflows32(
        memorySlotCount: memorySlotCount)
      
      if !overflows32 {
        return """
        uint listAddress32 = slotID * \(MemorySlot.reference32.size / 4);
        """
      } else {
        fatalError("Hello world.")
      }
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(functionSignature())
    {
      \(allocateThreadgroupMemory())
      
      if (crashBuffer[0] != 1) {
        return;
      }
      
      uint encodedVoxelCoords = atomsRemovedVoxelCoords[groupID];
      uint3 voxelCoords = \(VoxelResources.decode("encodedVoxelCoords"));
      uint voxelID =
      \(VoxelResources.generate("voxelCoords", worldDimension / 2));
      
      uint slotID = assignedSlotIDs[voxelID];
      uint headerAddress = slotID * \(MemorySlot.header.size / 4);
      \(initializeAddress32())
      
      // check the addressOccupiedMark of each atom in voxel
      uint beforeAtomCount = headers[headerAddress];
      uint afterAtomCount = 0;
      uint loopBound = ((beforeAtomCount + 127) / 128) * 128;
      for (uint i = localID; i < loopBound; i += 128) {
        // WARNING: Mask out operations for indices out of bounds.
        bool inLoopBounds = (i < beforeAtomCount);
        
        uint atomID = \(UInt32.max);
        bool shouldKeep = false;
        if (inLoopBounds) {
          atomID = references32[listAddress32 + i];
          if (addressOccupiedMarks[atomID] == 1) {
            shouldKeep = true;
          }
        }
        
        // Sanitize memory operations within the current block of 128.
        \(Reduction.groupGlobalBarrier())
        
        // WARNING: Sanitize local memory reads prior to this write.
        uint countBitsResult = \(Reduction.waveActiveCountBits("shouldKeep"));
        threadgroupMemory[\(waveID())] = countBitsResult;
        \(Reduction.groupLocalBarrier())
        
        \(Reduction.threadgroupSumPrimitive(offset: 0))
        
        uint localOffset = \(Reduction.wavePrefixSum("uint(shouldKeep)"));
        localOffset += threadgroupMemory[\(waveID())];
        localOffset += afterAtomCount;
        afterAtomCount += threadgroupMemory[4];
        \(Reduction.groupLocalBarrier())
        
        if (shouldKeep) {
          references32[listAddress32 + localOffset] = atomID;
        }
      }
      if (localID == 0) {
        headers[headerAddress] = afterAtomCount;
        headers[headerAddress + 1] = 0;
      }
      
      // if atoms remain, write to dense.rebuiltMarks
      if (afterAtomCount > 0) {
        rebuiltMarks[voxelID] = 1;
      } else {
        assignedVoxelCoords[slotID] = \(UInt32.max);
        assignedSlotIDs[voxelID] = \(UInt32.max);
      }
    }
    """
  }
}

extension BVHBuilder {
  func removeProcess3(commandList: CommandList) {
    commandList.withPipelineState(shaders.remove.process3) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      #if os(macOS)
      commandList.setBuffer(
        atoms.addressOccupiedMarks, index: 1)
      #else
      commandList.setDescriptor(
        handleID: atoms.addressOccupiedMarksHandleID, index: 1)
      #endif
      
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 2)
      #if os(macOS)
      commandList.setBuffer(
        voxels.dense.rebuiltMarks, index: 3)
      #else
      commandList.setDescriptor(
        handleID: voxels.dense.rebuiltMarksHandleID, index: 3)
      #endif
      
      commandList.setBuffer(
        voxels.sparse.assignedVoxelCoords, index: 4)
      commandList.setBuffer(
        voxels.sparse.atomsRemovedVoxelCoords, index: 5)
      commandList.setBuffer(
        voxels.sparse.headers, index: 6)
      commandList.setBuffer(
        voxels.sparse.references32, index: 7)
      
      let offset = GeneralCounters.offset(.atomsRemovedVoxelCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
