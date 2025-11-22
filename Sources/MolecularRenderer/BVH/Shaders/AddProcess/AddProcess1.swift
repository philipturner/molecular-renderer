extension AddProcess {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(movedCount + addedCount, 1, 1)
  // threadgroup memory 4096 B
  //
  // set the addressOccupiedMark to 1
  // set the atom and motion vector
  // write to group.addedMarks
  // write to dense.atomicCounters with 8 partial sums
  // save the relativeOffsets
  static func createSource1(
    supports16BitTypes: Bool,
    worldDimension: Float
  ) -> String {
    // atoms.*
    // voxels.group.addedMarks
    // voxels.dense.atomicCounters
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void addProcess1(
        \(CrashBuffer.functionArguments),
        \(AtomResources.functionArguments(supports16BitTypes)),
        device uint *voxelGroupAddedMarks [[buffer(9)]],
        device atomic_uint *atomicCounters [[buffer(10)]],
        uint globalID [[thread_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      \(AtomResources.functionArguments(supports16BitTypes))
      RWStructuredBuffer<uint> voxelGroupAddedMarks : register(u9);
      RWStructuredBuffer<uint> atomicCounters : register(u10);
      groupshared uint cachedRelativeOffsets[8 * 128];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        \(AtomResources.rootSignatureArguments(supports16BitTypes))
        "UAV(u9),"
        "UAV(u10),"
      )]
      void addProcess1(
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
    
    func castHalf4(_ input: String) -> String {
      if supports16BitTypes {
        return "half4(\(input))"
      } else {
        return input
      }
    }
    
    func atomicFetchAdd() -> String {
      Reduction.atomicFetchAdd(
        buffer: "atomicCounters",
        address: "address",
        operand: "1",
        output: "offset")
    }
    
    func castUShort4(_ input: String) -> String {
      #if os(macOS)
      "ushort4(\(input))"
      #else
      input
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(AtomStyles.createAtomRadii(AtomStyles.radii))
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
      //
      // WARNING: Never read from transactionAtoms again. Always read from
      // the address space, which has the correct radius.
      uint atomID = transactionIDs[removedCount + globalID];
      float4 atom = transactionAtoms[globalID];
      
      // Pack the atomic number and radius^2 into the 4th component.
      {
        uint atomicNumber = uint(atom[3]);
        float radius = atomRadii[atomicNumber];
        uint bitPattern = \(Shader.asuint)(radius * radius);
        bitPattern &= 0xFFFFFF00;
        bitPattern |= atomicNumber & 0xFF;
        atom.w = \(Shader.asfloat)(bitPattern);
      }
      
      // Compute the motion vector.
      float4 motionVector = 0;
      if (globalID < movedCount) {
        float4 previousAtom = atoms[atomID];
        motionVector = previousAtom - atom;
      }
      
      // Write the state to the address space.
      atoms[atomID] = atom;
      motionVectors[atomID] = \(castHalf4("motionVector"));
      addressOccupiedMarks[atomID] = 1;
      
      \(computeLoopBounds(worldDimension: worldDimension))
      
      // Initialize the cached offsets for debugging purposes.
      for (uint i = 0; i < 8; ++i) {
        uint address = i;
        address = address * 128 + localID;
        cachedRelativeOffsets[address] = \(UInt16.max);
      }
      
      // Iterate over the footprint on the 3D grid.
      for (uint z = 0; z < loopEnd[2]; ++z) {
        for (uint y = 0; y < loopEnd[1]; ++y) {
          for (uint x = 0; x < loopEnd[0]; ++x) {
            uint3 actualXYZ = uint3(x, y, z);
            actualXYZ = reorderBackward(actualXYZ, permutationID);
            
            // Write the voxel group added mark.
            {
              uint3 voxelCoordinates = largeVoxelMin + actualXYZ;
              voxelCoordinates /= 4;
              uint address =
              \(VoxelResources.generate("voxelCoordinates", worldDimension / 8));
              voxelGroupAddedMarks[address] = 1;
            }
            
            // Perform the atomic fetch-add.
            uint offset;
            {
              uint3 voxelCoordinates = largeVoxelMin + actualXYZ;
              uint address =
              \(VoxelResources.generate("voxelCoordinates", worldDimension / 2));
              address = (address * 8) + (atomID % 8);
              \(atomicFetchAdd())
            }
            
            // Save the offset in the cache.
            {
              uint address = z * 4 + y * 2 + x;
              address = address * 128 + localID;
              cachedRelativeOffsets[address] = offset;
            }
          }
        }
      }
      
      // Read the cached offsets.
      \(Reduction.waveLocalBarrier())
      uint4 outputOffsets[2];
      \(Shader.unroll)
      for (uint i = 0; i < 8; ++i) {
        uint address = i * 128 + localID;
        uint offset = cachedRelativeOffsets[address];
        outputOffsets[i / 4][i % 4] = offset;
      }
      
      // Write the offsets to device memory.
      relativeOffsets1[globalID] = \(castUShort4("outputOffsets[0]"));
      if (loopEnd[2] == 2) {
        relativeOffsets2[globalID] = \(castUShort4("outputOffsets[1]"));
      }
    }
    """
  }
}

extension BVHBuilder {
  func addProcess1(
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    guard let transactionArgs else {
      fatalError("Transaction arguments were not set.")
    }
    
    commandList.withPipelineState(shaders.add.process1) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      atoms.setBufferBindings(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        transactionArgs: transactionArgs)
      
      commandList.setBuffer(
        voxels.group.addedMarks, index: 9)
      commandList.setBuffer(
        voxels.dense.atomicCounters, index: 10)
      
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
