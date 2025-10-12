func createRayIntersector(worldDimension: Float) -> String {
  func resultArgument() -> String {
    #if os(macOS)
    "thread IntersectionResult &result"
    #else
    "inout IntersectionResult result"
    #endif
  }
  
  // atoms
  // group.occupiedMarks
  // dense.assignedSlotIDs
  // sparse.memorySlots [32, 16]
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
    
    IntersectionResult intersect(IntersectionQuery query) {
      // Prepare the intersection result.
      IntersectionResult intersect;
      intersect.accept = false;
      intersect.distance = 1e38;
      
      // Deactivate ray tracing for primary ray.
      
      // Check whether we found a hit.
      if (intersect.distance < 1e38) {
        intersect.accept = true;
      }
      
      return intersect;
    }
  };
  """
}
