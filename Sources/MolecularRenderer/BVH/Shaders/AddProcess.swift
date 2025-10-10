// First step: update the positions and motion vectors in the address space
// in the first kernel
struct AddProcess {
  static func createSource1(worldDimension: Int) -> String {
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void addProcess1(
        \(AtomResources.functionArguments),
        device uint *voxelGroupMarks [[buffer(8)]],
        device atomic_uint *atomicCounters [[buffer(9)]],
        uint globalID [[thread_position_in_grid]],
        uint localID [[thread_position_in_threadgroup]])
      """
      #else
      """
      \(AtomResources.functionArguments)
      RWStructuredBuffer<uint> voxelGroupMarks : register(u8);
      RWStructuredBuffer<uint> atomicCounters : register(u9);
      
      [numthreads(128, 1, 1)]
      [RootSignature(
        \(AtomResources.rootSignatureArguments)
        "UAV(u8),"
        "UAV(u9),"
      )]
      void addProcess1(
        uint globalID : SV_DispatchThreadID,
        uint localID : SV_GroupThreadID)
      """
      #endif
    }
    
    func writeMotionVector() -> String {
      #if os(macOS)
      "motionVectors[atomID] = half4(motionVector);"
      #else
      "motionVectors[atomID] = motionVector;"
      #endif
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(AtomStyles.createAtomRadii(AtomStyles.radii))
    \(TransactionArgs.shaderDeclaration)
    
    \(functionSignature())
    {
      uint removedCount = transactionArgs.removedCount;
      uint movedCount = transactionArgs.movedCount;
      uint addedCount = transactionArgs.addedCount;
      if (globalID >= movedCount + addedCount) {
        return;
      }
      
      // Retrieve the atom.
      uint atomID = transactionIDs[removedCount + globalID];
      float4 atom = transactionAtoms[removedCount + globalID];
      uint atomicNumber = uint(atom[3]);
      float radius = atomRadii[atomicNumber];
      
      // Compute the motion vector.
      float4 motionVector = 0;
      if (globalID < movedCount) {
        float4 previousAtom = atoms[atomID];
        motionVector = previousAtom - atom;
      }
      
      // Write the state to the address space.
      atoms[atomID] = atom;
      \(writeMotionVector())
      occupied[atomID] = 1;
      
      // Place the atom in the grid of 0.25 nm voxels.
      float3 scaledPosition = atom.xyz + float(\(worldDimension / 2));
      scaledPosition /= 0.25;
      float scaledRadius = radius / 0.25;
      
      // Generate the bounding box.
      float3 boxMin = floor(scaledPosition - scaledRadius);
      float3 boxMax = ceil(scaledPosition + scaledRadius);
      
      // Return early if out of bounds.
      bool3 returnEarly = (boxMin < 0);
      returnEarly = or(returnEarly, boxMax > float(\(worldDimension * 4)));
      if (any(returnEarly)) {
        return;
      }
      
      // Generate the voxel coordinates.
      uint3 smallVoxelMin = uint3(boxMin);
      uint3 smallVoxelMax = uint3(boxMax);
      uint3 largeVoxelMin = smallVoxelMin / 8;
      
      // Pre-compute the footprint.
      uint3 dividingLine = (largeVoxelMin + 1) * 8;
      dividingLine = min(dividingLine, smallVoxelMax);
      dividingLine = max(dividingLine, smallVoxelMin);
      int3 footprintLow = int3(dividingLine - smallVoxelMin);
      int3 footprintHigh = int3(smallVoxelMax - dividingLine);
      
      // Determine the loop bounds.
      uint3 loopEnd = select(uint3(1, 1, 1),
                             uint3(2, 2, 2),
                             footprintHigh > 0);
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
    
    commandList.withPipelineState(shaders.addProcess1) {
      atomResources.setBufferBindings(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        transactionArgs: transactionArgs)
      
      commandList.setBuffer(
        voxelResources.voxelGroupMarks, index: 8)
      commandList.setBuffer(
        voxelResources.atomicCounters, index: 9)
      
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
