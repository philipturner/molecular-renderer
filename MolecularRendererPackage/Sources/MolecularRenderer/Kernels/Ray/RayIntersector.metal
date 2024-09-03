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
  uchar3 largeCellID;
};

struct IntersectionQuery {
  bool isAORay;
  float3 rayOrigin;
  float3 rayDirection;
  
  float maximumAODistance() {
    constexpr float maximumRayHitTime = 1.0;
    constexpr float voxelDiagonalWidth = 0.25 * 1.73205;
    return maximumRayHitTime + voxelDiagonalWidth;
  }
  
  bool exceededAOTime(DDA dda, float voxelMaximumTime) {
    float maximumHitTime = dda.maximumHitTime(voxelMaximumTime);
    if (isAORay) {
      return maximumHitTime > maximumAODistance();
    } else {
      return false;
    }
  }
};

// MARK: - Intersector Class

struct RayIntersector {
  constant BVHArguments *bvhArgs;
  device uint4 *largeCellMetadata;
  device ushort2 *compactedSmallCellMetadata;
  device ushort *smallAtomReferences;
  device half4 *convertedAtoms;
  
  IntersectionResult intersect(IntersectionQuery intersectionQuery) {
    bool returnEarly;
    const DDA dda(intersectionQuery.rayOrigin,
                  intersectionQuery.rayDirection,
                  bvhArgs,
                  &returnEarly);
    
    IntersectionResult result;
    result.accept = false;
    if (returnEarly) {
      return result;
    }
    
    ushort3 progress = ushort3(0);
    while (!result.accept) {
      uint4 largeMetadata;
      ushort2 smallMetadata;
      uchar3 largeCellID;
      float voxelMaximumTime;
      
      // Inner 'while' loop to find the next voxel.
      while (true) {
        ushort3 cellCoordinates = dda
          .cellCoordinates(progress, bvhArgs->smallVoxelCount);
        largeCellID = uchar3(cellCoordinates / 8);
        
        {
          float3 lowerCorner = bvhArgs->worldMinimum;
          lowerCorner += float3(largeCellID) * 2;
          
          ushort3 cellCoordinates = ushort3(lowerCorner + 64);
          cellCoordinates /= 2;
          
          uint address = VoxelAddress::generate(64, cellCoordinates);
          largeMetadata = largeCellMetadata[address];
        }
        
        {
          ushort3 localOffset = cellCoordinates % 8;
          ushort localAddress = VoxelAddress::generate(8, localOffset);
          uint compactedGlobalAddress = largeMetadata[0] * 512 + localAddress;
          smallMetadata = compactedSmallCellMetadata[compactedGlobalAddress];
        }
        
        // Save the voxel maximum time.
        voxelMaximumTime = dda.voxelMaximumTime(progress);
        
        // Increment to the next voxel.
        progress = dda.increment(progress);
        
        // Exit the inner loop.
        if (smallMetadata[1] > 0) {
          break;
        }
        if (!dda.continueLoop(progress, bvhArgs->smallVoxelCount)) {
          break;
        }
        if (intersectionQuery.exceededAOTime(dda, voxelMaximumTime)) {
          break;
        }
      }
      
      {
        // Exit the outer 'while' loop.
        if (!dda.continueLoop(progress, bvhArgs->smallVoxelCount)) {
          break;
        }
        if (intersectionQuery.exceededAOTime(dda, voxelMaximumTime)) {
          break;
        }
        
        // Skip this iteration of the outer 'while' loop.
        if (smallMetadata[1] == 0) {
          continue;
        }
      }
      
      // Set the origin register.
      float3 origin = intersectionQuery.rayOrigin;
      origin -= bvhArgs->worldMinimum;
      origin -= float3(largeCellID) * 2;
      
      // Set the loop bounds register.
      uint referenceCursor = largeMetadata[2] + smallMetadata[0];
      uint referenceEnd = referenceCursor + smallMetadata[1];
      
      // Set the distance register.
      result.distance = dda.maximumHitTime(voxelMaximumTime);
      
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
          c = fma(float(oc.x), float(oc.x), c);
          c = fma(float(oc.y), float(oc.y), c);
          c = fma(float(oc.z), float(oc.z), c);
          
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
      if (result.distance < dda.maximumHitTime(voxelMaximumTime)) {
        result.accept = true;
        result.largeCellID = largeCellID;
      }
    }
    
    return result;
  }
};

#endif // RAY_TRAVERSAL_H
