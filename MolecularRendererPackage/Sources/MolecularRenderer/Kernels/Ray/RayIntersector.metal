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
  bool isAORay;
  float3 rayOrigin;
  float3 rayDirection;
  
  bool exceededAOTime(float voxelMaximumHitTime) {
    if (isAORay) {
      // This cutoff is parameterized for small voxels, where the distance
      // is 0.25 nm. If you switch to testing a different voxel size, the
      // parameter must change.
      constexpr float cutoff = 1 + 0.25 * 1.732051;
      return voxelMaximumHitTime > cutoff;
    } else {
      return false;
    }
  }
};

// MARK: - Intersector Class

struct RayIntersector {
  device half4 *convertedAtoms;
  device ushort *smallAtomReferences;
  device uint4 *largeCellMetadata;
  device ushort2 *compactedSmallCellMetadata;
  
  uint4 largeMetadata(float3 largeLowerCorner) {
    float3 coordinates = (largeLowerCorner + 64) / 2;
    float address =
    VoxelAddress::generate<float, float>(64, coordinates);
    return largeCellMetadata[uint(address)];
  }
  
  ushort2 smallMetadata(float3 largeLowerCorner,
                        float3 smallLowerCorner,
                        uint4 largeMetadata) {
    float3 coordinates = (smallLowerCorner - largeLowerCorner) / 0.25;
    float localAddress =
    VoxelAddress::generate<float, float>(8, coordinates);
    
    uint compactedGlobalAddress =
    largeMetadata[0] * 512 + uint(localAddress);
    return compactedSmallCellMetadata[compactedGlobalAddress];
  }
  
  IntersectionResult intersect(IntersectionQuery intersectionQuery) {
    float3 cursorCellBorder;
    const DDA dda(&cursorCellBorder,
                  intersectionQuery.rayOrigin,
                  intersectionQuery.rayDirection);
    
    IntersectionResult result;
    result.accept = false;
    
    bool outOfBounds = false;
    while (!outOfBounds) {
      bool acceptVoxel = false;
      uint acceptedBorderCode;
      
      {
        // Compute the voxel maximum time.
        float voxelMaximumHitTime = dda
          .voxelMaximumHitTime(cursorCellBorder,
                               intersectionQuery.rayOrigin);
        if (intersectionQuery.exceededAOTime(voxelMaximumHitTime)) {
          outOfBounds = true;
          break;
        }
        
        // Compute the lower corner.
        float3 smallLowerCorner = dda.cellLowerCorner(cursorCellBorder);
        float3 largeLowerCorner = 2 * floor(smallLowerCorner / 2);
        if (any(largeLowerCorner < -64) || any(largeLowerCorner >= 64)) {
          outOfBounds = true;
          break;
        }
        
        // If the large cell has small cells, proceed.
        uint4 largeMetadata = this->largeMetadata(largeLowerCorner);
        if (largeMetadata[0] > 0) {
          // If the small cell has atoms, test them.
          ushort2 smallMetadata = this->smallMetadata(largeLowerCorner,
                                                      smallLowerCorner,
                                                      largeMetadata);
          if (smallMetadata[1] > 0) {
            acceptVoxel = true;
            
            float3 coordinates = (cursorCellBorder + 64) / 0.25;
            uint3 cellIndex = uint3(coordinates);
            acceptedBorderCode = 0;
            acceptedBorderCode += cellIndex[0] << 0;
            acceptedBorderCode += cellIndex[1] << 9;
            acceptedBorderCode += cellIndex[2] << 18;
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
      
      // Test the atoms in the accepted voxel.
      if (acceptVoxel) {
        uint3 cellIndex;
        cellIndex[0] = (acceptedBorderCode >> 0) & 511;
        cellIndex[1] = (acceptedBorderCode >> 9) & 511;
        cellIndex[2] = (acceptedBorderCode >> 18) & 511;
        float3 coordinates = float3(cellIndex);
        float3 acceptedSmallCellBorder = (coordinates * 0.25) - 64;
        
        float voxelMaximumHitTime = dda
          .voxelMaximumHitTime(acceptedSmallCellBorder,
                               intersectionQuery.rayOrigin);
        float3 smallLowerCorner = dda.cellLowerCorner(acceptedSmallCellBorder);
        float3 largeLowerCorner = 2 * floor(smallLowerCorner / 2);
        uint4 largeMetadata = this->largeMetadata(largeLowerCorner);
        ushort2 smallMetadata = this->smallMetadata(largeLowerCorner,
                                                    smallLowerCorner,
                                                    largeMetadata);
        
        // Set the origin register.
        float3 origin = intersectionQuery.rayOrigin;
        origin -= largeLowerCorner;
        
        // Set the loop bounds register.
        uint referenceCursor = largeMetadata[2] + smallMetadata[0];
        uint referenceEnd = referenceCursor + smallMetadata[1];
        
        // Set the distance register.
        result.distance = voxelMaximumHitTime;
        
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
