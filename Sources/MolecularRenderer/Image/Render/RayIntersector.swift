private func outOfBoundsStatement(
  argument: String,
  minimum: String,
  maximum: String
) -> String {
  let lhs = "\(argument) < \(minimum)"
  let rhs = "\(argument) >= \(maximum)"
  return "any(\(Shader.or(lhs, rhs)))"
}

private func createIntersectAtom() -> String {
  func resultArgument() -> String {
    #if os(macOS)
    "thread IntersectionResult &result"
    #else
    "inout IntersectionResult result"
    #endif
  }
  
  return """
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
  """
}

private func createTestCell() -> String {
  func resultArgument() -> String {
    #if os(macOS)
    "thread IntersectionResult &result"
    #else
    "inout IntersectionResult result"
    #endif
  }
  
  return """
  void testCell(\(resultArgument()))
  """
}

private func createFillMemoryTape(
  worldDimension: Float
) -> String {
  // Arguments for fillMemoryTape that vary by platform.
  func fillMemoryTapeArguments() -> String {
    #if os(macOS)
    """
    thread float3 &largeCellBorder,
    thread bool &outOfBounds,
    thread uint &acceptedLargeVoxelCount,
    """
    #else
    """
    inout float3 largeCellBorder,
    inout bool outOfBounds,
    inout uint acceptedLargeVoxelCount,
    """
    #endif
  }
  
  func float3(_ repeatedValue: Float) -> String {
    "float3(\(repeatedValue), \(repeatedValue), \(repeatedValue))"
  }
  
  func checkMemoryTape() -> String {
    outOfBoundsStatement(
      argument: "largeLowerCorner",
      minimum: "\(-worldDimension / 2)",
      maximum: "\(worldDimension / 2)")
  }
  
  return """
  void fillMemoryTape(\(fillMemoryTapeArguments())
                        IntersectionQuery query,
                        DDA dda)
  {
    float3 sign =
    \(Shader.select(float3(-1), float3(1), "dda.dtdx >= 0"));
    float3 flippedRayOrigin = query.rayOrigin * sign;
    float3 flippedRayDirection = query.rayDirection * sign;
    
    while (acceptedLargeVoxelCount < 8) {
      // Check whether the DDA has gone out of bounds.
      float3 largeLowerCorner = dda.cellLowerCorner(largeCellBorder);
      if (\(checkMemoryTape())) {
        outOfBounds = true;
        break;
      }
      
      // Read the 8 nm scoped mark.
      
      // Branch on the 8 nm scoped mark.
      {
        float3 nextTimes = dda
          .nextTimes(largeCellBorder, query.rayOrigin);
        uint3 voxelCoords = getVoxelCoords(largeLowerCorner);
        uint slotID = getSlotID(largeLowerCorner);
        
        // If the large cell has small cells, proceed.
        if (slotID != \(UInt32.max)) {
          float3 currentTimes = nextTimes - dda.dx * dda.dtdx;
          
          // Find the minimum time.
          float minimumTime = 1e38;
          minimumTime = min(currentTimes[0], minimumTime);
          minimumTime = min(currentTimes[1], minimumTime);
          minimumTime = min(currentTimes[2], minimumTime);
          minimumTime = max(minimumTime, float(0));
          
          // Encode the key.
          uint2 largeKey;
          largeKey[0] = \(VoxelResources.encode("voxelCoords"));
          largeKey[1] = \(Shader.asuint)(minimumTime);
          
          // Write to the memory tape.
          uint address = acceptedLargeVoxelCount;
          address = address * 64 + localID;
          memoryTape[address] = largeKey;
          acceptedLargeVoxelCount += 1;
        }
        
        // Increment to the next large voxel.
        largeCellBorder = dda.nextBorder(largeCellBorder, nextTimes);
      }
      
      {
        // If false, retrieve the 32 nm scoped mark.
        
        // Set the group spacing to 8 nm or 32 nm based on the mark.
        float groupSpacing = 8;
        float groupSpacingRecip = \(Float(1) / 8);
        
        // Jump forward to the next cell group.
        //
        // Optimization:
        // - Flip the negative-pointing axes upside down.
        // - Reduces the divergence cost of the ceil/floor instructions by 2x.
        // - Correct the final value upon exit.
      }
    }
  }
  """
}

// BVH traversal algorithm for primary rays. These rays must jump very
// large distances, but have minimal divergence.
private func createIntersectPrimary(
  worldDimension: Float
) -> String {
  func checkPrimary() -> String {
    outOfBoundsStatement(
      argument: "smallLowerCorner",
      minimum: "0",
      maximum: "2")
  }
  
  return """
  IntersectionResult intersectPrimary(IntersectionQuery query) {
    // Initialize the outer DDA.
    float3 largeCellBorder;
    DDA largeDDA;
    largeDDA.initializeLarge(largeCellBorder,
                             query.rayOrigin,
                             query.rayDirection);
    
    IntersectionResult result;
    result.accept = false;
    bool outOfBounds = false;
    
    while (!outOfBounds) {
      // Loop over ~8 large voxels.
      uint acceptedLargeVoxelCount = 0;
      fillMemoryTape(largeCellBorder,
                     outOfBounds,
                     acceptedLargeVoxelCount,
                     intersectionQuery,
                     largeDDA);
      
      
      \(Reduction.waveLocalBarrier())
      
      // Allocate the small DDA.
      float3 smallCellBorder;
      DDA smallDDA;
      bool initializedSmallDDA = false;
      
      // Allocate the large cell metadata.
      uint largeVoxelCursor = 0;
      uint slotID;
      uint smallHeaderBase;
      
      // The ray's origin relative to the lower corner of the 2 nm voxel.
      float3 shiftedRayOrigin;
      
      // Loop over the few small voxels that are occupied.
      //
      // This is a measure to minimize the divergence of the ray-sphere
      // intersection tests.
      while (largeVoxelCursor < acceptedLargeVoxelCount) {
        uint acceptedSmallHeader = 0;
        float acceptedVoxelMaximumHitTime;
        
        // Loop over all ~64 small voxels.
        while (acceptedSmallHeader == 0) {
          // Regenerate the small DDA.
          //
          // This is a measure to minimize the divergence from the variation
          // in number of intersected small voxels per large voxel.
          if (!initializedSmallDDA) {
            // Read from the memory tape.
            uint address = largeVoxelCursor;
            address = address * 64 + localID;
            uint2 largeKey = memoryTape[address];
            
            // Decode the key.
            uint encodedVoxelCoords = largeKey[0];
            uint3 voxelCoords = \(VoxelResources.decode("encodedVoxelCoords"));
            float minimumTime = \(Shader.asuint)(largeKey[1]);
            
            // Retrieve the large cell metadata.
            slotID = getSlotID(voxelCoords);
            uint headerAddress = slotID * \(MemorySlot.header.size / 4);
            smallHeaderBase = headerAddress +
            \(MemorySlot.smallHeadersOffset / 4);
            
            // Compute the voxel bounds.
            shiftedRayOrigin = query.rayOrigin;
            shiftedRayOrigin += \(worldDimension / 2);
            shiftedRayOrigin -= float3(voxelCoords) * 2;
            
            // Initialize the inner DDA.
            float3 direction = query.rayDirection;
            float3 origin = shiftedRayOrigin + minimumTime * direction;
            origin = max(origin, 0);
            origin = min(origin, 2);
            smallDDA.initializeSmall(smallCellBorder,
                                     origin,
                                     direction);
            initializedSmallDDA = true;
          }
          
          // Check whether the DDA has gone out of bounds.
          float3 smallLowerCorner = smallDDA.cellLowerCorner(smallCellBorder);
          if (\(checkPrimary())) {
            largeVoxelCursor += 1;
            initializedSmallDDA = false;
            break; // search for occupied 2 nm voxel
          }
          
          // Retrieve the small cell metadata.
          uint smallHeader = getSmallHeader(smallHeaderBase,
                                            smallLowerCorner);
          float3 nextTimes = smallDDA
            .nextTimes(smallCellBorder, shiftedRayOrigin);
          
          // Save the voxel maximum time.
          if (smallHeader > 0) {
            acceptedSmallHeader = smallHeader;
            acceptedVoxelMaximumHitTime = smallDDA
              .voxelMaximumHitTime(smallCellBorder, nextTimes);
          }
          
          // Increment to the next small voxel.
          smallCellBorder = smallDDA.nextBorder(smallCellBorder, nextTimes);
        }
        
        // Test the atoms.
        if (acceptedSmallHeader > 0) {
          // Set the distance register.
          result.distance = acceptedVoxelMaximumHitTime;
          
          // Test the atoms in the accepted voxel.
          testCell(result,
                   shiftedRayOrigin,
                   intersectionQuery.rayDirection,
                   largeMetadata,
                   acceptedSmallMetadata);
          
          // Check whether we found a hit.
          if (result.distance < acceptedVoxelMaximumHitTime) {
            result.accept = true;
            outOfBounds = true;
            largeVoxelCursor = acceptedLargeVoxelCount;
          }
        }
      }
    }
    
    return result;
  }
  """
}

// BVH traversal algorithm for AO rays. These rays terminate after
// traveling 1 nm, but their divergence can be extremely high.
private func createIntersectAO(
  worldDimension: Float
) -> String {
  func cutoffAO() -> Float {
    Float(1) + 0.25 * Float(3).squareRoot()
  }
  
  func checkAO() -> String {
    outOfBoundsStatement(
      argument: "smallLowerCorner",
      minimum: "\(-worldDimension / 2)",
      maximum: "\(worldDimension / 2)")
  }
  
  return """
  IntersectionResult intersectAO(IntersectionQuery query) {
    float3 smallCellBorder;
    DDA dda;
    dda.initializeSmall(smallCellBorder,
                        query.rayOrigin,
                        query.rayDirection);
    
    IntersectionResult result;
    result.accept = false;
    
    while (!result.accept) {
      // Compute the voxel maximum time.
      float3 nextTimes = dda
        .nextTimes(smallCellBorder, query.rayOrigin);
      float voxelMaximumHitTime = dda
        .voxelMaximumHitTime(smallCellBorder, nextTimes);
      
      // Check whether the DDA has gone out of bounds.
      float3 smallLowerCorner = dda.cellLowerCorner(smallCellBorder);
      if (voxelMaximumHitTime > \(cutoffAO()) || \(checkAO())) {
        break;
      }
      
      // Retrieve the slot ID.
      float3 largeLowerCorner = 2 * floor(smallLowerCorner / 2);
      uint3 voxelCoords = getVoxelCoords(largeLowerCorner);
      uint slotID = getSlotID(voxelCoords);
      
      // If the large cell has small cells, proceed.
      if (slotID != \(UInt32.max)) {
        uint headerAddress = slotID * \(MemorySlot.header.size / 4);
        uint smallHeaderBase = headerAddress +
        \(MemorySlot.smallHeadersOffset / 4);
        
        float3 relativeSmallLowerCorner = smallLowerCorner - largeLowerCorner;
        uint smallHeader = getSmallHeader(smallHeaderBase,
                                          relativeSmallLowerCorner);
        
        if (smallHeader > 0) {
          // Set the distance register.
          result.distance = voxelMaximumHitTime;
          
          uint listAddress = slotID * \(MemorySlot.reference32.size / 4);
          uint listAddress16 = slotID * \(MemorySlot.reference16.size / 2);
          
          // Set the loop bounds register.
          uint referenceCursor = smallHeader & 0xFFFF;
          uint referenceEnd = smallHeader >> 16;
          referenceCursor += listAddress16;
          referenceEnd += listAddress16;
          
          // Prevent infinite loops from corrupted BVH data.
          referenceEnd = min(referenceEnd, referenceCursor + 128);
          
          // Test every atom in the voxel.
          while (referenceCursor < referenceEnd) {
            uint reference16 = references16[referenceCursor];
            uint atomID = references32[listAddress + reference16];
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
  """
}

func createRayIntersector(worldDimension: Float) -> String {
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
    device uint *headers;
    device uint *references32;
    device ushort *references16;
    threadgroup uint2 *memoryTape;
    """
    #else
    """
    RWStructuredBuffer<float4> atoms;
    RWStructuredBuffer<uint> voxelGroupOccupiedMarks;
    RWStructuredBuffer<uint> assignedSlotIDs;
    RWStructuredBuffer<uint> headers;
    RWStructuredBuffer<uint> references32;
    RWBuffer<uint> references16;
    """
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
  
  \(createIntersectAtom())
  
  struct RayIntersector {
    \(bvhBuffers())
    uint localID;
    
    // Compute address in UInt32 because world dimensions over 512 nm reach
    // the limit of FP32 mantissa. Now the limit is 2048 nm, set by both the
    // precision of UInt32 and the precision of FP32 when computing addresses
    // for 8 nm voxel groups.
    uint3 getVoxelCoords(float3 largeLowerCorner) {
      float3 coordinates = largeLowerCorner + \(worldDimension / 2);
      coordinates /= 2;
      return uint3(coordinates);
    }
    
    uint getSlotID(uint3 voxelCoords) {
      uint voxelID =
      \(VoxelResources.generate("voxelCoords", worldDimension / 2));
      return assignedSlotIDs[voxelID];
    }
    
    uint getSmallHeader(uint smallHeaderBase,
                        float3 relativeSmallLowerCorner)
    {
      float3 coordinates = relativeSmallLowerCorner / 0.25;
      float address =
      \(VoxelResources.generate("coordinates", 8));
      return headers[smallHeaderBase + uint(address)];
    }
    
    \(createFillMemoryTape(worldDimension: worldDimension))
    
    \(createIntersectPrimary(worldDimension: worldDimension))
    
    \(createIntersectAO(worldDimension: worldDimension))
  };
  """
}
