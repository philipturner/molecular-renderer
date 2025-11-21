extension RebuildProcess {
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  // threadgroup memory 2068 B
  //
  // # Phase I
  //
  // loop over the cuboid bounding box of each atom
  // atomically accumulate into threadgroupCounters
  //
  // # Phase II
  //
  // read 4 voxels per thread, on 128 threads in parallel
  // prefix sum over 512 small voxels (SIMD + group reduction)
  //   save the prefix sum result for Phase IV
  // if reference count is too large, crash w/ diagnostic info
  // write reference count into memory slot header
  //
  // # Phase III
  //
  // loop over a 3x3x3 grid of small voxels for each atom
  // run the cube-sphere test and mask out voxels outside the 2 nm bound
  // atomically accumulate into threadgroupCounters
  // write a 16-bit reference to sparse.memorySlots
  //
  // # Phase IV
  //
  // restore the prefix sum result
  // read end of reference list from threadgroupCounters
  // if atom count is zero, output UInt32(0)
  // otherwise
  //   store two offsets relative to the slot's region for 16-bit references
  //   compress these two 16-bit offsets into a 32-bit word
  static func createSource2(
    worldDimension: Float,
    vendor: Vendor,
    supports16BitTypes: Bool
    ) -> String {
    // atoms.atoms
    // voxels.dense.assignedSlotIDs
    // voxels.sparse.rebuiltVoxelCoords
    // voxels.sparse.memorySlots [32, 16]
    func functionSignature() -> String {
      #if os(macOS)
      return """
      kernel void rebuildProcess2(
        \(CrashBuffer.functionArguments),
        device float4 *atoms [[buffer(1)]],
        device uint *assignedSlotIDs [[buffer(2)]],
        device uint *rebuiltVoxelCoords [[buffer(3)]],
        device uint *headers [[buffer(4)]],
        device uint *references32 [[buffer(5)]],
        device ushort *references16 [[buffer(6)]],
        uint groupID [[threadgroup_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      func references16ArgumentType() -> String {
        if supports16BitTypes {
          return "RWStructuredBuffer<uint16_t>"
        } else {
          return "RWBuffer<uint>"
        }
      }

      func references16RootSignatureArgument() -> String {
        if supports16BitTypes {
          return "UAV(u6)"
        } else {
          return "DescriptorTable(UAV(u6, numDescriptors = 1))"
        }
      }

      return """
      \(CrashBuffer.functionArguments)
      RWStructuredBuffer<float4> atoms : register(u1);
      RWStructuredBuffer<uint> assignedSlotIDs : register(u2);
      RWStructuredBuffer<uint> rebuiltVoxelCoords : register(u3);
      RWStructuredBuffer<uint> headers : register(u4);
      RWStructuredBuffer<uint> references32 : register(u5);
      \(references16ArgumentType()) references16 : register(u6);
      groupshared uint threadgroupMemory[517];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "UAV(u1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
        "UAV(u5),"
        "\(references16RootSignatureArgument()),"
      )]
      void rebuildProcess2(
        uint groupID : SV_GroupID,
        uint localID : SV_GroupThreadID)
      """
      #endif
    }
    
    func allocateThreadgroupMemory() -> String {
      #if os(macOS)
      "threadgroup uint threadgroupMemory[517];"
      #else
      ""
      #endif
    }
    
    // Better memory locality in the Z axis for ray tracing.
    func threadgroupAddress(_ i: String) -> String {
      "256 * (localID / 64) + (\(i) * 64) + (localID % 64)"
    }

    func generateSmallAddress() -> String {
      if vendor == .amd {
        // Bypass a strange driver crash.
        return """
        uint3 xyz_AMD = uint3(xyz);
        uint address = \(VoxelResources.generate("xyz_AMD", 8));
        """
      } else {
        return """
        float address = \(VoxelResources.generate("xyz", 8));
        """
      }
    }
    
    func atomicFetchAdd() -> String {
      #if os(macOS)
      let buffer = "(threadgroup atomic_uint*)threadgroupMemory"
      #else
      let buffer = "threadgroupMemory"
      #endif
      
      return Reduction.atomicFetchAdd(
        buffer: buffer,
        address: "uint(address)",
        operand: "1",
        output: "offset")
    }
    
    func castUShort(_ input: String) -> String {
      if supports16BitTypes {
        return "uint16_t(\(input))"
      } else {
        return input
      }
    }

    func waveID() -> String {
      "localID / \(Reduction.waveGetLaneCount())"
    }

    return """
    \(Shader.importStandardLibrary)
    
    \(cubeSphereTest())
    
    \(functionSignature())
    {
      \(allocateThreadgroupMemory())
      
      if (crashBuffer[0] != 1) {
        return;
      }
      
      uint encodedVoxelCoords = rebuiltVoxelCoords[groupID];
      uint3 voxelCoords = \(VoxelResources.decode("encodedVoxelCoords"));
      uint voxelID =
      \(VoxelResources.generate("voxelCoords", worldDimension / 2));
      float3 lowerCorner = float3(voxelCoords) * 2;
      lowerCorner -= float(\(worldDimension / 2));
      
      uint slotID = assignedSlotIDs[voxelID];
      uint headerAddress = slotID * \(MemorySlot.header.size / 4);
      uint listAddress = slotID * \(MemorySlot.reference32.size / 4);
      uint atomCount = headers[headerAddress];
      
      \(Shader.unroll)
      for (uint i = 0; i < 4; ++i) {
        uint address = \(threadgroupAddress("i"));
        threadgroupMemory[address] = 0;
      }
      \(Reduction.groupLocalBarrier())

      // =======================================================================
      // ===                            Phase I                              ===
      // =======================================================================
      
      for (uint i = localID; i < atomCount; i += 128) {
        uint atomID = references32[listAddress + i];
        float4 atom = atoms[atomID];
        \(computeLoopBounds())
        
        // Iterate over the footprint on the 3D grid.
        for (float z = boxMin[2]; z < boxMax[2]; ++z) {
          for (float y = boxMin[1]; y < boxMax[1]; ++y) {
            for (float x = boxMin[0]; x < boxMax[0]; ++x) {
              float3 xyz = float3(x, y, z);
              \(generateSmallAddress())
              
              uint offset;
              \(atomicFetchAdd())
            }
          }
        }
      }
      \(Reduction.groupLocalBarrier())
      
      // =======================================================================
      // ===                            Phase II                             ===
      // =======================================================================
      
      uint countersSum = 0;
      uint4 counters = 0;
      \(Shader.unroll)
      for (uint i = 0; i < 4; ++i) {
        uint address = \(threadgroupAddress("i"));
        uint temp = threadgroupMemory[address];
        counters[i] = countersSum;
        countersSum += temp;
      }
      \(Reduction.groupLocalBarrier())
      
      uint wavePrefixSum = \(Reduction.wavePrefixSum("countersSum"));
      uint waveInclusiveSum = wavePrefixSum + countersSum;
      uint waveTotalSum;
      if (\(Reduction.waveGetLaneCount()) == 32) {
        waveTotalSum =
        \(Reduction.waveReadLaneAt("waveInclusiveSum", laneID: 31));
      } else {
        // Branch for 64-wide wavefronts.
        waveTotalSum =
        \(Reduction.waveReadLaneAt("waveInclusiveSum", laneID: 63));
      }
      
      threadgroupMemory[512 + \(waveID())] = waveTotalSum;
      \(Reduction.groupLocalBarrier())
      \(Reduction.threadgroupSumPrimitive(offset: 512))
      
      // Incorporate all contributions to the prefix sum.
      counters += wavePrefixSum;
      counters += threadgroupMemory[512 + \(waveID())];
      \(Shader.unroll)
      for (uint i = 0; i < 4; ++i) {
        uint address = \(threadgroupAddress("i"));
        threadgroupMemory[address] = counters[i];
      }
      \(Reduction.groupLocalBarrier())
      
      uint referenceCount = threadgroupMemory[516];
      if (referenceCount > 20480) {
        if (localID == 0) {
          bool acquiredLock = false;
          \(CrashBuffer.acquireLock(errorCode: 4))
          if (acquiredLock) {
            crashBuffer[1] = voxelCoords.x;
            crashBuffer[2] = voxelCoords.y;
            crashBuffer[3] = voxelCoords.z;
            crashBuffer[4] = referenceCount;
          }
        }
        return;
      }
      if (localID == 0) {
        headers[headerAddress + 1] = referenceCount;
      }
      
      // =======================================================================
      // ===                            Phase III                            ===
      // =======================================================================
      
      uint64_t listAddress16 = uint64_t(slotID) * \(MemorySlot.reference16.size / 2);
      
      for (uint i = localID; i < atomCount; i += 128) {
        uint atomID = references32[listAddress + i];
        float4 atom = atoms[atomID];
        \(computeLoopBounds())
        
        // Iterate over the footprint on the 3D grid.
        \(Shader.loop)
        for (float z = 0; z < 3; ++z) {
          \(Shader.unroll)
          for (float y = 0; y < 3; ++y) {
            \(Shader.unroll)
            for (float x = 0; x < 3; ++x) {
              float3 xyz = boxMin + float3(x, y, z);
              
              // Narrow down the cells with a cube-sphere intersection test.
              bool intersected = cubeSphereTest(xyz, atom);
              if (intersected && all(xyz < boxMax)) {
                \(generateSmallAddress())
                
                uint offset;
                \(atomicFetchAdd())
                
                references16[listAddress16 + uint64_t(offset)] = \(castUShort("i"));
              }
            }
          }
        }
      }
      \(Reduction.groupLocalBarrier())
      
      // =======================================================================
      // ===                            Phase IV                             ===
      // =======================================================================
      
      uint smallHeaderBase = headerAddress +
      \(MemorySlot.smallHeadersOffset / 4);
      
      \(Shader.unroll)
      for (uint i = 0; i < 4; ++i) {
        uint address = \(threadgroupAddress("i"));
        uint counterAfter = threadgroupMemory[address];
        uint counterBefore = counters[i];
        
        uint headerValue = 0;
        if (counterAfter > counterBefore) {
          headerValue = counterBefore | (counterAfter << 16);
        }
        headers[smallHeaderBase + address] = headerValue;
      }
    }
    """
  }
}

extension BVHBuilder {
  func rebuildProcess2(commandList: CommandList) {
    commandList.withPipelineState(shaders.rebuild.process2) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      commandList.setBuffer(
        atoms.atoms, index: 1)
      commandList.setBuffer(
        voxels.dense.assignedSlotIDs, index: 2)
      commandList.setBuffer(
        voxels.sparse.rebuiltVoxelCoords, index: 3)
      commandList.setBuffer(
        voxels.sparse.headers, index: 4)
      commandList.setBuffer(
        voxels.sparse.references32, index: 5)
      voxels.sparse.bindReferences16(
        commandList: commandList, index: 6)
      
      let offset = GeneralCounters.offset(.rebuiltVoxelCount)
      commandList.dispatchIndirect(
        buffer: counters.general,
        offset: offset)
    }
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
