extension RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(memorySlotCount, 1, 1)
  // threadgroup memory 20 B
  //
  // scan for slots with no assigned voxel
  // create compact list of these slots (SIMD + group + global reduction)
  // write to sparse.vacantSlotIDs
  static func createSource4() -> String {
    func constantArgs() -> String {
      """
      struct ConstantArgs {
        uint memorySlotCount;
      };
      """
    }
    
    // counters.general.vacantSlotCount
    // voxels.sparse.assignedVoxelCoords
    // voxels.sparse.vacantSlotIDs
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void removeProcess4(
        \(CrashBuffer.functionArguments),
        constant ConstantArgs &constantArgs [[buffer(1)]],
        device atomic_uint *vacantSlotCount [[buffer(2)]],
        device uint *assignedVoxelCoords [[buffer(3)]],
        device uint *vacantSlotIDs [[buffer(4)]],
        uint globalID [[thread_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(CrashBuffer.functionArguments)
      ConstantBuffer<ConstantArgs> constantArgs : register(b1);
      RWStructuredBuffer<uint> vacantSlotCount : register(u2);
      RWStructuredBuffer<uint> assignedVoxelCoords : register(u3);
      RWStructuredBuffer<uint> vacantSlotIDs : register(u4);
      groupshared uint threadgroupMemory[5];
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "RootConstants(b1, num32BitConstants = 1),"
        "UAV(u2),"
        "UAV(u3),"
        "UAV(u4),"
      )]
      void removeProcess4(
        uint globalID : SV_DispatchThreadID,
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
    
    return """
    \(Shader.importStandardLibrary)
    
    \(constantArgs())
    
    \(functionSignature())
    {
      \(allocateThreadgroupMemory())
      
      if (crashBuffer[0] != 1) {
        return;
      }
      
      bool isVacant = false;
      if (globalID < constantArgs.memorySlotCount) {
        uint voxelCoords = assignedVoxelCoords[globalID];
        isVacant = (voxelCoords != \(UInt32.max));
      }
      uint countBitsResult = \(Reduction.waveActiveCountBits("isVacant"));
      //threadgroupMemory[localID / 32] = countBitsResult;
      \(Reduction.barrier())
      
      // Threadgroup-scoped reduction. Be careful with barriers in diverging
      // control flow; behavior is nominally undefined.
      //
      // TODO: New primitive that operates on 5 slots of memory, returns a full
      // prefix sum of 4 components and writes them back into TG memory.
      // - Takes the offset into the threadgroup allocation as an argument.
      // - Assumes the allocation is called 'threadgroupMemory'.
    }
    """
  }
}

extension BVHBuilder {
  func removeProcess4(commandList: CommandList) {
    commandList.withPipelineState(shaders.remove.process4) {
      counters.crashBuffer.setBufferBindings(
        commandList: commandList)
      
      // Bind the constant arguments.
      struct ConstantArgs {
        var memorySlotCount: UInt32 = .zero
      }
      var constantArgs = ConstantArgs()
      constantArgs.memorySlotCount = UInt32(voxels.memorySlotCount)
      commandList.set32BitConstants(
        constantArgs, index: 1)
      
      commandList.setBuffer(
        counters.general,
        index: 2,
        offset: GeneralCounters.offset(.vacantSlotCount))
      commandList.setBuffer(
        voxels.sparse.assignedVoxelCoords, index: 3)
      commandList.setBuffer(
        voxels.sparse.vacantSlotIDs, index: 4)
      
      // Determine the dispatch grid size.
      func createGroupCount32() -> SIMD3<UInt32> {
        var groupCount: Int = voxels.memorySlotCount
        
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
}
