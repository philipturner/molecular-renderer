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
  constant BVHArguments *bvhArgs;
  device half4 *convertedAtoms;
  device ushort *smallAtomReferences;
  device uint4 *largeCellMetadata;
  device ushort2 *compactedSmallCellMetadata;
  
  IntersectionResult intersect(IntersectionQuery intersectionQuery) {
    float3 cellBorder;
    const DDA dda(intersectionQuery.rayOrigin,
                  intersectionQuery.rayDirection,
                  &cellBorder);
    
    IntersectionResult result;
    result.accept = false;
    
    while (!result.accept) {
      float voxelMaximumHitTime;
      float3 lowerCorner;
      uint4 largeMetadata;
      ushort2 smallMetadata;
      
      // Inner 'while' loop to find the next voxel.
      bool exitOuterLoop = false;
      while (true) {
        // Save the voxel maximum time.
        voxelMaximumHitTime = dda
          .voxelMaximumHitTime(cellBorder, intersectionQuery.rayOrigin);
        
        // Exit the outer 'while' loop.
        if (intersectionQuery.exceededAOTime(voxelMaximumHitTime)) {
          exitOuterLoop = true;
          break;
        }
        
        // Compute the cell's lower corner.
        float3 cellLowerCorner = dda.cellLowerCorner(cellBorder);
        
        // Exit the outer 'while' loop.
        if (any(cellLowerCorner < -64) || any(cellLowerCorner >= 64)) {
          exitOuterLoop = true;
          break;
        }
        
        // Compute the large cell ID.
        float3 largeCellID = floor(32 + cellLowerCorner / 2);
        
        // Save the lower corner.
        {
          lowerCorner = bvhArgs->worldMinimum;
          lowerCorner += float3(largeCellID) * 2;
        }
        
        // Save the large metadata.
        {
          float address = VoxelAddress::generate<float, float>(64, largeCellID);
          largeMetadata = largeCellMetadata[uint(address)];
        }
        
        // Save the small metadata.
        {
          float3 smallCellID = 256 + cellLowerCorner / 0.25;
          half3 localOffset = half3(smallCellID - largeCellID * 8);
          half localAddress = VoxelAddress::generate<half, half>(8, localOffset);
          
          uint compactedGlobalAddress =
          largeMetadata[0] * 512 + ushort(localAddress);
          smallMetadata = compactedSmallCellMetadata[compactedGlobalAddress];
        }
        
        // Increment to the next voxel.
        cellBorder = dda
          .increment(cellBorder, intersectionQuery.rayOrigin);
        
        // Exit the inner 'while' loop.
        if (smallMetadata[1] > 0) {
          break;
        }
      }
      
      // Exit the outer 'while' loop.
      if (exitOuterLoop) {
        break;
      }
      
      // Set the origin register.
      float3 origin = intersectionQuery.rayOrigin;
      origin -= lowerCorner;
      
      // Set the loop bounds register.
      uint referenceCursor = largeMetadata[2] + smallMetadata[0];
      uint referenceEnd = referenceCursor + smallMetadata[1];
      
      // Set the distance register.
      result.distance = voxelMaximumHitTime;
      
      // Test every atom in the voxel.
      while (referenceCursor < referenceEnd) {
        // Locate the atom.
        ushort reference = smallAtomReferences[referenceCursor];
        referenceCursor += 1;
        
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
      }
      
      // Check whether we found a hit.
      if (result.distance < voxelMaximumHitTime) {
        result.accept = true;
      }
    }
    
    return result;
  }
};

#endif // RAY_TRAVERSAL_H
