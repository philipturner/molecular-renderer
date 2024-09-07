//
//  RayIntersector.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/14/23.
//

#ifndef RAY_TRAVERSAL_H
#define RAY_TRAVERSAL_H

#include <metal_stdlib>
#include "../Ray/DDA.metal"
#include "../Utilities/Constants.metal"
using namespace metal;

// MARK: - Data Structures

struct IntersectionResult {
  bool accept;
  uint atomID;
  float distance;
};

struct IntersectionQuery {
  float3 rayOrigin;
  float3 rayDirection;
};

// MARK: - Intersector Class

struct RayIntersector {
  device half4 *convertedAtoms;
  device ushort *smallAtomReferences;
  device uint4 *largeCellMetadata;
  device uint4 *compactedLargeCellMetadata;
  device ushort2 *compactedSmallCellMetadata;
  threadgroup uint2 *threadgroupMemory;
  ushort threadIndex;
  
  uint globalFaultCounter = 0;
  uint errorCode = 0;
  static uint maxFaultCounter() {
    return 500;
  }
  
  // Retrieves the large cell metadata from the dense buffer.
  uint4 largeMetadata(float3 largeLowerCorner) const
  {
    float3 coordinates = (largeLowerCorner + 64) / 2;
    float address =
    VoxelAddress::generate<float, float>(64, coordinates);
    return largeCellMetadata[uint(address)];
  }
  
  // Retrieves the small cell metadata from the compacted buffer.
  ushort2 smallMetadata(float3 relativeSmallLowerCorner,
                        uint compactedLargeCellID) const
  {
    float3 coordinates = relativeSmallLowerCorner / 0.25;
    float localAddress =
    VoxelAddress::generate<float, float>(8, coordinates);
    
    uint compactedGlobalAddress =
    compactedLargeCellID * 512 + uint(localAddress);
    return compactedSmallCellMetadata[compactedGlobalAddress];
  }
  
  // Fills the memory tape with large voxels.
  void fillMemoryTape(thread float3 &largeCellBorder,
                      thread bool &outOfBounds,
                      thread ushort &acceptedLargeVoxelCount,
                      IntersectionQuery intersectionQuery,
                      const DDA dda)
  {
    while (acceptedLargeVoxelCount < 8) {

      
      // Compute the lower corner.
      float3 smallLowerCorner = dda.cellLowerCorner(largeCellBorder);
      if (any(smallLowerCorner < -64 || smallLowerCorner >= 64)) {
        outOfBounds = true;
        return;
      }
      
      // Retrieve the large metadata.
      float3 largeLowerCorner = 2 * floor(smallLowerCorner / 2);
      uint4 largeMetadata = this->largeMetadata(largeLowerCorner);
      float3 currentTimes =
      (largeCellBorder - intersectionQuery.rayOrigin) * dda.dtdx;
      
      if (largeMetadata[0] > 0) {
        // Find the minimum time.
        float minimumTime = 1e38;
        minimumTime = min(currentTimes[0], minimumTime);
        minimumTime = min(currentTimes[1], minimumTime);
        minimumTime = min(currentTimes[2], minimumTime);
        minimumTime = max(minimumTime, float(0));
        
        // Encode the key.
        uint2 largeKey;
        largeKey[0] = largeMetadata[0];
        largeKey[1] = as_type<uint>(minimumTime);
        
        // Write to threadgroup memory.
        ushort threadgroupAddress = acceptedLargeVoxelCount;
        threadgroupAddress = threadgroupAddress * 64 + threadIndex;
        threadgroupMemory[threadgroupAddress] = largeKey;
        acceptedLargeVoxelCount += 1;
      }
      
      // Fast forward to the next large voxel.
      float3 nextTimes = currentTimes + float3(dda.dx) * dda.dtdx;
      largeCellBorder = dda.nextSmallBorder(largeCellBorder, nextTimes);
    }
  }
  
  // Intersects all of the atoms in a small voxel.
  void testCell(thread IntersectionResult &result,
                float3 origin,
                float3 direction,
                uint4 largeMetadata,
                ushort2 smallMetadata)
  {
    // Set the loop bounds register.
    uint referenceCursor = largeMetadata[2] + smallMetadata[0];
    uint referenceEnd = referenceCursor + smallMetadata[1];
    
    // Test every atom in the voxel.
    while (referenceCursor < referenceEnd) {
      // Locate the atom.
      ushort reference = smallAtomReferences[referenceCursor];
      
      // Retrieve the atom.
      uint atomID = largeMetadata[1] + reference;
      half4 atom = convertedAtoms[atomID];
      
      // Run the intersection test.
      {
        float3 oc = origin - float3(atom.xyz);
        float b2 = dot(float3(oc), direction);
        
        float radius = float(atom.w);
        float c = -radius * radius;
        c = fma(oc.x, oc.x, c);
        c = fma(oc.y, oc.y, c);
        c = fma(oc.z, oc.z, c);
        
        float disc4 = b2 * b2 - c;
        if (disc4 > 0) {
          float distance = fma(-disc4, rsqrt(disc4), -b2);
          if (distance >= 0 && distance < result.distance) {
            result.atomID = atomID;
            result.distance = distance;
          }
        }
      }
      
      // Increment to the next reference.
      referenceCursor += 1;
    }
  }
  
  // BVH traversal algorithm for primary rays. These rays must jump very
  // large distances, but have minimal divergence.
  IntersectionResult intersectPrimary(IntersectionQuery intersectionQuery) {
    // Initialize the outer DDA.
    float3 largeCellBorder;
    const DDA largeDDA(&largeCellBorder,
                       intersectionQuery.rayOrigin,
                       intersectionQuery.rayDirection,
                       2.00);
    
    IntersectionResult result;
    result.accept = false;
    bool outOfBounds = false;
    
    while (!outOfBounds) {
      // Loop over ~8 large voxels.
      ushort acceptedLargeVoxelCount = 0;
      fillMemoryTape(largeCellBorder,
                     outOfBounds,
                     acceptedLargeVoxelCount,
                     intersectionQuery,
                     largeDDA);
      
      simdgroup_barrier(mem_flags::mem_threadgroup);
      
      // Allocate the small DDA.
      float3 smallCellBorder;
      DDA smallDDA;
      bool initializedSmallDDA = false;
      
      // Allocate the large cell metadata.
      ushort largeVoxelCursor = 0;
      uint4 largeMetadata;
      float3 shiftedRayOrigin;
      
      // Loop over the few small voxels that are occupied.
      while (largeVoxelCursor < acceptedLargeVoxelCount) {
        ushort2 acceptedSmallMetadata = 0;
        float acceptedVoxelMaximumHitTime;
        
        // Loop over all ~64 small voxels.
        while (acceptedSmallMetadata[1] == 0) {
//          globalFaultCounter += 1;
//          if (globalFaultCounter > maxFaultCounter()) {
//            errorCode = 3;
//            return result;
//          }
          
          // Regenerate the small DDA.
          if (!initializedSmallDDA) {
            // Read from threadgroup memory.
            ushort threadgroupAddress = largeVoxelCursor;
            threadgroupAddress = threadgroupAddress * 64 + threadIndex;
            uint2 largeKey = threadgroupMemory[threadgroupAddress];
            
            // Decode the key.
            uint compactedLargeCellID = largeKey[0];
            float minimumTime = as_type<float>(largeKey[1]);
            
            // Retrieve the large cell metadata.
            largeMetadata = compactedLargeCellMetadata[compactedLargeCellID];
            uchar4 compressedCellCoordinates = as_type<uchar4>(largeMetadata[0]);
            float3 cellCoordinates = float3(compressedCellCoordinates.xyz);
            largeMetadata[0] = compactedLargeCellID;
            
            // Compute the voxel bounds.
            shiftedRayOrigin = intersectionQuery.rayOrigin;
            shiftedRayOrigin -= -64;
            shiftedRayOrigin -= cellCoordinates * 2;
            
            // Initialize the inner DDA.
            float3 direction = intersectionQuery.rayDirection;
            float3 origin = shiftedRayOrigin + minimumTime * direction;
            origin = max(origin, 0);
            origin = min(origin, 2);
            smallDDA = DDA(&smallCellBorder,
                           origin,
                           direction,
                           0.25);
            initializedSmallDDA = true;
          }
          
          // Check whether the DDA has gone out of bounds.
          float3 smallLowerCorner = smallDDA.cellLowerCorner(smallCellBorder);
          if (any(smallLowerCorner < 0 || smallLowerCorner >= 2)) {
            largeVoxelCursor += 1;
            initializedSmallDDA = false;
            break; // search for occupied voxel
          }
          
          // Retrieve the small cell metadata.
          ushort2 smallMetadata = this->smallMetadata(smallLowerCorner,
                                                      largeMetadata[0]);
          float3 nextTimes = smallDDA
            .nextTimes(smallCellBorder, shiftedRayOrigin);
          
          // Save the voxel maximum time.
          if (smallMetadata[1] > 0) {
            acceptedSmallMetadata = smallMetadata;
            acceptedVoxelMaximumHitTime = smallDDA
              .voxelMaximumHitTime(smallCellBorder, nextTimes);
          }
          
          // Increment to the next small voxel.
          smallCellBorder = smallDDA.nextSmallBorder(smallCellBorder, nextTimes);
        }
        
        // Test the atoms.
        if (acceptedSmallMetadata[1] > 0) {
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
  
  // BVH traversal algorithm for AO rays. These rays terminate after traveling
  // 1 nm, but their divergence can be extremely high.
  IntersectionResult intersectAO(IntersectionQuery intersectionQuery)
  {
    float3 smallCellBorder;
    const DDA dda(&smallCellBorder,
                  intersectionQuery.rayOrigin,
                  intersectionQuery.rayDirection,
                  0.25);
    
    IntersectionResult result;
    result.accept = false;
    bool outOfBounds = false;
    
    while (!outOfBounds) {
//      globalFaultCounter += 1;
//      if (globalFaultCounter > maxFaultCounter()) {
//        errorCode = 1;
//        return result;
//      }
      
      uint4 largeMetadata;
      float3 largeLowerCorner;
      ushort2 smallMetadata = 0;
      float voxelMaximumHitTime;
      
      while (smallMetadata[1] == 0) {
//        globalFaultCounter += 1;
//        if (globalFaultCounter > maxFaultCounter()) {
//          errorCode = 2;
//          return result;
//        }
        
        // Compute the voxel maximum time.
        float3 nextTimes = dda
          .nextTimes(smallCellBorder, intersectionQuery.rayOrigin);
        voxelMaximumHitTime = dda
          .voxelMaximumHitTime(smallCellBorder, nextTimes);
        
        // This cutoff is parameterized for small voxels, where the distance
        // is 0.25 nm. If you switch to testing a different voxel size, the
        // parameter must change.
        constexpr float cutoff = 1 + 0.25 * 1.732051;
        
        // Check whether the DDA has gone out of bounds.
        float3 smallLowerCorner = dda.cellLowerCorner(smallCellBorder);
        if ((voxelMaximumHitTime > cutoff) ||
            any(smallLowerCorner < -64 || smallLowerCorner >= 64)) {
          outOfBounds = true;
          break; // search for occupied voxel
        }
        
        // If the large cell has small cells, proceed.
        largeLowerCorner = 2 * floor(smallLowerCorner / 2);
        largeMetadata = this->largeMetadata(largeLowerCorner);
        if (largeMetadata[0] > 0) {
          float3 relativeSmallLowerCorner = smallLowerCorner - largeLowerCorner;
          smallMetadata = this->smallMetadata(relativeSmallLowerCorner,
                                              largeMetadata[0]);
        }
        
        // Increment to the next small voxel.
        smallCellBorder = dda.nextSmallBorder(smallCellBorder, nextTimes);
      }
      
      if (smallMetadata[1] > 0) {
        // Set the origin register.
        float3 shiftedRayOrigin = intersectionQuery.rayOrigin;
        shiftedRayOrigin -= largeLowerCorner;
        
        // Set the distance register.
        result.distance = voxelMaximumHitTime;
        
        // Test the atoms in the accepted voxel.
        testCell(result,
                 shiftedRayOrigin,
                 intersectionQuery.rayDirection,
                 largeMetadata,
                 smallMetadata);
        
        // Check whether we found a hit.
        if (result.distance < voxelMaximumHitTime) {
          result.accept = true;
          outOfBounds = true;
        }
      }
    }
    
    return result;
  }
};

#endif // RAY_TRAVERSAL_H
