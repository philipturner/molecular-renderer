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
    
    uint compactedGlobalAddress =
    largeMetadata[0] * 512 + uint(localAddress);
    return compactedSmallCellMetadata[compactedGlobalAddress];
  }
  
  void searchForNextCell(thread float3 &cursorCellBorder,
                         thread bool &acceptVoxel,
                         thread bool &outOfBounds,
                         thread uint *acceptedBorderCode,
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
        acceptVoxel = true;
        
        float3 coordinates1 = (largeLowerCorner + 64) / 2;
        float3 coordinates2 = (smallLowerCorner - largeLowerCorner) / 0.25;
        uint3 cellIndex1 = uint3(coordinates1);
        uint3 cellIndex2 = uint3(coordinates2);
        
        uint borderCode1 = 0;
        borderCode1 += cellIndex1[0] << 0;
        borderCode1 += cellIndex1[1] << 6;
        borderCode1 += cellIndex1[2] << 12;
        
        uint borderCode2 = 0;
        borderCode2 += cellIndex2[0] << 0;
        borderCode2 += cellIndex2[1] << 3;
        borderCode2 += cellIndex2[2] << 6;
        
        *acceptedBorderCode = (borderCode1 << 9) | borderCode2;
        
//        float3 coordinates = (cursorCellBorder + 64) / 0.25;
//        uint3 cellIndex = uint3(coordinates);
//        *acceptedBorderCode = 0;
//        *acceptedBorderCode += cellIndex[0] << 0;
//        *acceptedBorderCode += cellIndex[1] << 9;
//        *acceptedBorderCode += cellIndex[2] << 18;
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
      bool acceptVoxel = false;
      uint acceptedBorderCode = 0;
      
      while (!acceptVoxel) {
        searchForNextCell(cursorCellBorder,
                          acceptVoxel,
                          outOfBounds,
                          &acceptedBorderCode,
                          intersectionQuery,
                          dda);
        if (outOfBounds) {
          break;
        }
      }
      
      if (acceptVoxel) {
//        uint3 cellIndex;
//        cellIndex[0] = (acceptedBorderCode >> 0) & 511;
//        cellIndex[1] = (acceptedBorderCode >> 9) & 511;
//        cellIndex[2] = (acceptedBorderCode >> 18) & 511;
//        float3 coordinates = float3(cellIndex);
//        float3 acceptedSmallCellBorder = (coordinates * 0.25) - 64;
        
        uint borderCode1 = acceptedBorderCode >> 9;
        uint borderCode2 = acceptedBorderCode & 511;
        
        uint3 cellIndex1;
        cellIndex1[0] = (borderCode1 >> 0) & 63;
        cellIndex1[1] = (borderCode1 >> 6) & 63;
        cellIndex1[2] = (borderCode1 >> 12) & 63;
        
        uint3 cellIndex2;
        cellIndex2[0] = (borderCode2 >> 0) & 7;
        cellIndex2[1] = (borderCode2 >> 3) & 7;
        cellIndex2[2] = (borderCode2 >> 6) & 7;
        
        float3 coordinates1 = float3(cellIndex1);
        float3 coordinates2 = float3(cellIndex2);
        float3 largeLowerCorner = coordinates1 * 2 - 64;
        float3 smallLowerCorner = coordinates2 * 0.25 + largeLowerCorner;
        float3 acceptedSmallCellBorder = smallLowerCorner;
        acceptedSmallCellBorder +=
        select(float3(-dda.dx), float3(0), dda.dtdx >= 0);
        
        float voxelMaximumHitTime = dda
          .voxelMaximumHitTime(acceptedSmallCellBorder,
                               intersectionQuery.rayOrigin);
//        float3 smallLowerCorner = dda.cellLowerCorner(acceptedSmallCellBorder);
//        float3 largeLowerCorner = 2 * floor(smallLowerCorner / 2);
        uint4 largeMetadata = this->largeMetadata(largeLowerCorner);
        ushort2 smallMetadata = this->smallMetadata(largeLowerCorner,
                                                    smallLowerCorner,
                                                    largeMetadata);
        
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
