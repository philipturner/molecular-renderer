func createRayIntersector(worldDimension: Float) -> String {
  func resultArgument() -> String {
    #if os(macOS)
    "thread IntersectionResult &result"
    #else
    "inout IntersectionResult result"
    #endif
  }
  
  // atoms.atoms
  // voxels.group.occupiedMarks
  // voxels.dense.assignedSlotIDs
  // voxels.sparse.memorySlots [32, 16]
  func bvhBuffers() -> String {
    #if os(macOS)
    """
    device float4 *atoms;
    device uint *voxelGroupOccupiedMarks;
    device uint *assignedSlotIDs;
    device uint *memorySlots32;
    device ushort *memorySlots16;
    """
    #else
    """
    RWStructuredBuffer<float4> atoms;
    RWStructuredBuffer<uint> voxelGroupOccupiedMarks;
    RWStructuredBuffer<uint> assignedSlotIDs;
    RWStructuredBuffer<uint> memorySlots32;
    RWBuffer<uint> memorySlots16;
    """
    #endif
  }
  
  func memoryTapeArgument() -> String {
    #if os(macOS)
    "threadgroup uint2 *memoryTape;"
    #else
    ""
    #endif
  }
  
  return """
  \(createDDAUtility(worldDimension: worldDimension))
  
  struct IntersectionResult {
    bool accept;
    uint atomID;
    float distance;
  };
  
  struct IntersectionQuery {
    float3 rayOrigin;
    float3 rayDirection;
  };
  
  // Transform a 16-bit reference into a 32-bit reference prior to calling this
  // function, by fetching from the small voxel's list of ~3072 atom references.
  //
  // Will need to encode the memory slots as both an RWStructuredBuffer<uint>
  // and RWBuffer<uint> with DXGI_FORMAT_R16_UINT. Per small cell metadata can
  // be read as UInt32, then decoded into two UInt16 numbers with bitwise
  // operations. This decoding only happens once, not on every loop
  // iteration.
  //
  // reference16 = RWBuffer[loop iterator]
  // reference32 = RWStructuredBuffer[precomputed offset + reference16]
  // atom = addressSpace[reference32]
  void intersectAtom(\(resultArgument()),
                     IntersectionQuery query,
                     float4 atom,
                     uint atomID)
  {
    float3 oc = query.rayOrigin - atom.xyz;
    float b2 = dot(float3(oc), query.rayDirection);
    float c = dot(oc, oc) - atom.w;
    
    float disc4 = b2 * b2 - c;
    if (disc4 > 0) {
      float distance = -disc4 * rsqrt(disc4) - b2;
      if (distance >= 0 && distance < result.distance) {
        result.atomID = atomID;
        result.distance = distance;
      }
    }
  }
  
  struct RayIntersector {
    \(bvhBuffers())
    \(memoryTapeArgument())
    
    uint getSlotID(float3 largeLowerCorner) {
      float3 coordinates = largeLowerCorner + \(worldDimension / 2);
      coordinates /= 2;
      
      // Compute address in UInt32 because world dimensions over 512 nm reach
      // the limit of FP32 mantissa. Now the limit is 2048 nm, set by both the
      // precision of UInt32 and the precision of FP32 when computing addresses
      // for 8 nm voxel groups.
      uint3 coordinatesInt = uint3(coordinates);
      uint address =
      \(VoxelResources.generate("coordinatesInt", worldDimension / 2));
      return assignedSlotIDs[address];
    }
    
    uint getSmallHeader(uint smallHeaderBase,
                        float3 relativeSmallLowerCorner)
    {
      float3 coordinates = relativeSmallLowerCorner / 0.25;
      float address =
      \(VoxelResources.generate("coordinates", 8));
      return memorySlots32[smallHeaderBase + uint(address)];
    }
    
    IntersectionResult intersect(IntersectionQuery query) {
      // Initialize the DDA.
      float3 smallCellBorder;
      DDA dda;
      dda.initialize(smallCellBorder,
                     query.rayOrigin,
                     query.rayDirection);
      
      // Prepare the intersection result.
      IntersectionResult result;
      result.accept = false;
      result.atomID = \(UInt32.max);
      result.distance = 1e38;
      
      uint loopIterationCount = 0;
      while (!result.accept) {
        // Prevent infinite loops from corrupted BVH data.
        loopIterationCount += 1;
        if (loopIterationCount >= 256) {
          break;
        }
        
        // Compute the voxel maximum time.
        float3 nextTimes = dda
          .nextTimes(smallCellBorder, query.rayOrigin);
        float voxelMaximumHitTime = dda
          .voxelMaximumHitTime(smallCellBorder, nextTimes);
        
        // Check whether the DDA has gone out of bounds.
        float3 smallLowerCorner = dda.cellLowerCorner(smallCellBorder);
        bool3 breakLoop = smallLowerCorner < \(-worldDimension / 2);
        breakLoop =
        \(Shader.or("breakLoop", "smallLowerCorner >= \(worldDimension / 2)"));
        if (any(breakLoop)) {
          break;
        }
        
        // Retrieve the slot ID.
        float3 largeLowerCorner = 2 * floor(smallLowerCorner / 2);
        uint slotID = getSlotID(largeLowerCorner);
        
        // If the large cell has small cells, proceed.
        if (slotID != \(UInt32.max)) {
          uint headerAddress = slotID * \(MemorySlot.totalSize / 4);
          uint smallHeaderBase = headerAddress +
          \(MemorySlot.offset(.headerSmall) / 4);
          uint listAddress = headerAddress +
          \(MemorySlot.offset(.referenceLarge) / 4);
          uint listAddress16 = headerAddress * 2 +
          \(MemorySlot.offset(.referenceSmall) / 2);
          
          float3 relativeSmallLowerCorner = smallLowerCorner - largeLowerCorner;
          uint smallHeader = getSmallHeader(smallHeaderBase,
                                            relativeSmallLowerCorner);
          
          if (smallHeader > 0) {
            // Set the distance register.
            result.distance = voxelMaximumHitTime;
            
            // Set the loop bounds register.
            uint referenceCursor = smallHeader & 0xFFFF;
            uint referenceEnd = smallHeader >> 16;
            referenceCursor += listAddress16;
            referenceEnd += listAddress16;
            
            // Prevent infinite loops from corrupted BVH data.
            referenceEnd = min(referenceEnd, referenceCursor + 128);
            
            // Test every atom in the voxel.
            while (referenceCursor < referenceEnd) {
              uint reference16 = memorySlots16[referenceCursor];
              uint atomID = memorySlots32[listAddress + reference16];
              float4 atom = atoms[atomID];
              
              intersectAtom(result,
                            query,
                            atom,
                            atomID);
              
              referenceCursor += 1;
            }
            
            // Check whether we found a hit.
            if (result.distance < voxelMaximumHitTime) {
              result.accept = true;
            }
          }
        }
        
        // Increment to the next small voxel.
        smallCellBorder = dda.nextBorder(smallCellBorder, nextTimes);
      }
      
      return result;
    }
  };
  """
}
