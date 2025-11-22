extension AddProcess {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(movedCount + addedCount, 1, 1)
  // threadgroup memory 4096 B
  //
  // read atom from address space
  // restore the relativeOffsets
  // read from dense.atomicCounters
  //   add to relativeOffset, generating the correct offset
  // read from dense.assignedSlotIDs
  // write a 32-bit reference into sparse.memorySlots
  static func createSource3(
    memorySlotCount: Int,
    supports16BitTypes: Bool,
    worldDimension: Float
  ) -> String {
    // atoms.*
    // voxels.dense.assignedSlotIDs
    // voxels.dense.atomicCounters
    // voxels.sparse.memorySlots.referenceLarge
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void addProcess3(
        \(CrashBuffer.functionArguments),
        \(AtomResources.functionArguments(supports16BitTypes)),
        device uint *assignedSlotIDs [[buffer(9)]],
        device uint *atomicCounters [[buffer(10)]],
        device uint *references32 [[buffer(11)]],
        uint globalID [[thread_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      \(AtomResources.functionArguments(supports16BitTypes))
      RWStructuredBuffer<uint> assignedSlotIDs : register(u9);
      RWStructuredBuffer<uint> atomicCounters : register(u10);
      RWStructuredBuffer<uint> references32 : register(u11);
      groupshared uint cachedRelativeOffsets[8 * 128];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        \(AtomResources.rootSignatureArguments(supports16BitTypes))
        "UAV(u9),"
        "UAV(u10),"
        "UAV(u11),"
      )]
      void addProcess3(
        uint globalID : SV_DispatchThreadID,
        uint localID : SV_GroupThreadID)
      """
      #endif
    }
    
    func allocateThreadgroupMemory() -> String {
      #if os(macOS)
      "threadgroup uint cachedRelativeOffsets[8 * 128];"
      #else
      ""
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(pickPermutation())
    \(reorderForward())
    \(reorderBackward())
    \(TransactionArgs.shaderDeclaration)
    
    \(functionSignature())
    {
      \(allocateThreadgroupMemory())
      
      if (crashBuffer[0] != 1) {
        return;
      }
      
      uint removedCount = transactionArgs.removedCount;
      uint movedCount = transactionArgs.movedCount;
      uint addedCount = transactionArgs.addedCount;
      if (globalID >= movedCount + addedCount) {
        return;
      }
      
      // Retrieve the atom.
      uint atomID = transactionIDs[removedCount + globalID];
      float4 atom = atoms[atomID];
      
      \(computeLoopBounds(worldDimension: worldDimension))
      
      // Read the offsets from device memory.
      uint4 inputOffsets[2];
      inputOffsets[0] = uint4(relativeOffsets1[globalID]);
      if (loopEnd[2] == 2) {
        inputOffsets[1] = uint4(relativeOffsets2[globalID]);
      }
      
      // Write the cached offsets.
      \(Shader.unroll)
      for (uint i = 0; i < 8; ++i) {
        uint address = i * 128 + localID;
        uint offset = inputOffsets[i / 4][i % 4];
        cachedRelativeOffsets[address] = offset;
      }
      \(Reduction.waveLocalBarrier())
      
      // Iterate over the footprint on the 3D grid.
      for (uint z = 0; z < loopEnd[2]; ++z) {
        for (uint y = 0; y < loopEnd[1]; ++y) {
          for (uint x = 0; x < loopEnd[0]; ++x) {
            uint3 actualXYZ = uint3(x, y, z);
            actualXYZ = reorderBackward(actualXYZ, permutationID);
            
            uint3 voxelCoordinates = largeVoxelMin + actualXYZ;
            uint voxelID =
            \(VoxelResources.generate("voxelCoordinates", worldDimension / 2));
            
            // Restore the offset from the cache.
            uint offset;
            {
              uint address = z * 4 + y * 2 + x;
              address = address * 128 + localID;
              offset = cachedRelativeOffsets[address];
            }
            
            // Include the prefix sum offset from the atomic counter.
            {
              uint address = voxelID;
              address = (address * 8) + (atomID % 8);
              offset += atomicCounters[address];
            }
            
            uint slotID = assignedSlotIDs[voxelID];
            uint listAddress = slotID * \(MemorySlot.reference32.size / 4);
            references32[listAddress + offset] = atomID;
          }
        }
      }
    }
    """
  }
}

extension BVHBuilder {
  func addProcess3(
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    guard let transactionArgs else {
      fatalError("Transaction arguments were not set.")
    }
    
    commandList.withPipelineState(shaders.add.process3) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      atoms.setBufferBindings(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        transactionArgs: transactionArgs)
      
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 9)
      commandList.setBuffer(
        voxels.dense.atomicCounters, index: 10)
      commandList.setBuffer(
        voxels.sparse.references32, index: 11)
      
      // Determine the dispatch grid size.
      func createGroupCount32() -> SIMD3<UInt32> {
        var groupCount: Int = .zero
        groupCount += Int(transactionArgs.movedCount)
        groupCount += Int(transactionArgs.addedCount)
        
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
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
