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
  threadgroup uint *threadgroupMemory;
  ushort threadIndex;
  
  uint4 largeMetadata(float3 largeLowerCorner) const
  {
    float3 coordinates = (largeLowerCorner + 64) / 2;
    float address =
    VoxelAddress::generate<float, float>(64, coordinates);
    return largeCellMetadata[uint(address)];
  }
  
  ushort2 smallMetadata(float3 largeLowerCorner,
                        float3 smallLowerCorner,
                        uint4 largeMetadata) const
  {
    float3 coordinates = (smallLowerCorner - largeLowerCorner) / 0.25;
    float localAddress =
    VoxelAddress::generate<float, float>(8, coordinates);
    
    uint compactedLargeCellID = largeMetadata[0];
    uint compactedGlobalAddress =
    compactedLargeCellID * 512 + uint(localAddress);
    return compactedSmallCellMetadata[compactedGlobalAddress];
  }
  
  void searchForNextCell(thread float3 &cursorCellBorder,
                         thread ushort &acceptedVoxelCount,
                         thread bool &outOfBounds,
                         IntersectionQuery intersectionQuery,
                         const DDA dda)
  {
    // Compute the lower corner.
    float3 smallLowerCorner = dda.cellLowerCorner(cursorCellBorder);
    float3 largeLowerCorner = 2 * floor(smallLowerCorner / 2);
    if (any(largeLowerCorner < -64) || any(largeLowerCorner >= 64)) {
      outOfBounds = true;
      return;
    }
    
    // If the large cell has small cells, proceed.
    uint4 largeMetadata = this->largeMetadata(largeLowerCorner);
    if (largeMetadata[0] > 0) {
      ushort2 smallMetadata = this->smallMetadata(largeLowerCorner,
                                                  smallLowerCorner,
                                                  largeMetadata);
      if (smallMetadata[1] > 0) {
        // Encode the small cell coordinates.
        float3 coordinates2 = (smallLowerCorner - largeLowerCorner) / 0.25;
        uint3 cellIndex2 = uint3(coordinates2);
        uint borderCode2 = 0;
        borderCode2 += cellIndex2[0] << 0;
        borderCode2 += cellIndex2[1] << 3;
        borderCode2 += cellIndex2[2] << 6;
        
        // Encode the compacted large cell ID.
        uint borderCode1 = largeMetadata[0];
        uint acceptedBorderCode = (borderCode1 << 9) | borderCode2;
        
        // Store to threadgroup memory.
        ushort threadgroupAddress = acceptedVoxelCount * 64 + threadIndex;
        threadgroupMemory[threadgroupAddress] = acceptedBorderCode;
        acceptedVoxelCount += 1;
      }
      
      // Increment to the next small voxel.
      cursorCellBorder = dda.nextSmallBorder(cursorCellBorder,
                                             intersectionQuery.rayOrigin);
    } else {
      // Fast forward to the next large voxel.
      cursorCellBorder = dda
        .nextLargeBorder(cursorCellBorder,
                         intersectionQuery.rayOrigin,
                         intersectionQuery.rayDirection);
    }
  }
  
  void testCell(thread IntersectionResult &result,
                float3 largeLowerCorner,
                uint4 largeMetadata,
                ushort2 smallMetadata,
                IntersectionQuery intersectionQuery,
                const DDA dda)
  {
    // Set the origin register.
    float3 origin = intersectionQuery.rayOrigin;
    origin -= largeLowerCorner;
    
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
        float b2 = dot(float3(oc), intersectionQuery.rayDirection);
        
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
  
  IntersectionResult intersectPrimary(IntersectionQuery intersectionQuery)
  {
    float3 cursorCellBorder;
    const DDA dda(&cursorCellBorder,
                  intersectionQuery.rayOrigin,
                  intersectionQuery.rayDirection);
    
    IntersectionResult result;
    result.accept = false;
    
    bool outOfBounds = false;
    while (!outOfBounds) {
      ushort acceptedVoxelCount = 0;
      while (acceptedVoxelCount < 16) {
        searchForNextCell(cursorCellBorder,
                          acceptedVoxelCount,
                          outOfBounds,
                          intersectionQuery,
                          dda);
        if (outOfBounds) {
          break;
        }
      }
      
      simdgroup_barrier(mem_flags::mem_threadgroup);
      
      for (ushort i = 0; i < acceptedVoxelCount; ++i) {
        // Read from threadgroup memory.
        ushort threadgroupAddress = i * 64 + threadIndex;
        uint acceptedBorderCode = threadgroupMemory[threadgroupAddress];
        
        // Retrieve the large cell metadata.
        uint compactedLargeCellID = acceptedBorderCode >> 9;
        uint4 largeMetadata = compactedLargeCellMetadata[compactedLargeCellID];
        uchar4 compressedCellCoordinates = as_type<uchar4>(largeMetadata[0]);
        uint3 cellIndex1 = uint3(compressedCellCoordinates.xyz);
        
        // Decode the small cell coordinates.
        uint borderCode2 = acceptedBorderCode & 511;
        uint3 cellIndex2;
        cellIndex2[0] = (borderCode2 >> 0) & 7;
        cellIndex2[1] = (borderCode2 >> 3) & 7;
        cellIndex2[2] = (borderCode2 >> 6) & 7;
        
        // Decode the lower corner.
        float3 coordinates1 = float3(cellIndex1);
        float3 coordinates2 = float3(cellIndex2);
        float3 largeLowerCorner = coordinates1 * 2 - 64;
        float3 smallLowerCorner = coordinates2 * 0.25 + largeLowerCorner;
        
        // Compute the voxel maximum time.
        float3 acceptedSmallCellBorder = smallLowerCorner;
        acceptedSmallCellBorder +=
        select(float3(-dda.dx), float3(0), dda.dtdx >= 0);
        float voxelMaximumHitTime = dda
          .voxelMaximumHitTime(acceptedSmallCellBorder,
                               intersectionQuery.rayOrigin);
        
        // Retrieve the small cell metadata.
        uint compactedGlobalAddress =
        compactedLargeCellID * 512 + borderCode2;
        ushort2 smallMetadata = compactedSmallCellMetadata[compactedGlobalAddress];
        
        // Set the distance register.
        result.distance = voxelMaximumHitTime;
        
        // Test the atoms in the accepted voxel.
        testCell(result,
                 largeLowerCorner,
                 largeMetadata,
                 smallMetadata,
                 intersectionQuery,
                 dda);
        
        // Check whether we found a hit.
        if (result.distance < voxelMaximumHitTime) {
          result.accept = true;
          outOfBounds = true;
          break; // for loop
        }
      }
    }
    
    return result;
  }
  
  IntersectionResult intersectAO(IntersectionQuery intersectionQuery)
  {
    float3 cursorCellBorder;
    const DDA dda(&cursorCellBorder,
                  intersectionQuery.rayOrigin,
                  intersectionQuery.rayDirection);
    
    IntersectionResult result;
    result.accept = false;
    
    while (!result.accept) {
      // Compute the voxel maximum time.
      float voxelMaximumHitTime = dda
        .voxelMaximumHitTime(cursorCellBorder,
                             intersectionQuery.rayOrigin);
      
      // This cutoff is parameterized for small voxels, where the distance
      // is 0.25 nm. If you switch to testing a different voxel size, the
      // parameter must change.
      constexpr float cutoff = 1 + 0.25 * 1.732051;
      
      // Compute the lower corner.
      float3 smallLowerCorner = dda.cellLowerCorner(cursorCellBorder);
      float3 largeLowerCorner = 2 * floor(smallLowerCorner / 2);
      
      // Check whether the DDA has gone out of bounds.
      if ((voxelMaximumHitTime > cutoff) ||
          any(largeLowerCorner < -64) ||
          any(largeLowerCorner >= 64)) {
        break;
      }
      
      // If the large cell has small cells, proceed.
      uint4 largeMetadata = this->largeMetadata(largeLowerCorner);
      if (largeMetadata[0] > 0) {
        ushort2 smallMetadata = this->smallMetadata(largeLowerCorner,
                                                    smallLowerCorner,
                                                    largeMetadata);
        if (smallMetadata[1] > 0) {
          // Set the distance register.
          result.distance = voxelMaximumHitTime;
          
          // Test the atoms in the accepted voxel.
          testCell(result,
                   largeLowerCorner,
                   largeMetadata,
                   smallMetadata,
                   intersectionQuery,
                   dda);
          
          // Check whether we found a hit.
          if (result.distance < voxelMaximumHitTime) {
            result.accept = true;
          }
        }
      }
      
      // Increment to the next small voxel.
      cursorCellBorder = dda.nextSmallBorder(cursorCellBorder,
                                             intersectionQuery.rayOrigin);
    }
    
    return result;
  }
};

#endif // RAY_TRAVERSAL_H
