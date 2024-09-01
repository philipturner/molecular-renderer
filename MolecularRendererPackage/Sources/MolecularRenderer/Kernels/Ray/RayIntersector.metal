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
  
  float maximumAODistance() {
    constexpr float maximumRayHitTime = 1.0;
    constexpr float voxelDiagonalWidth = 0.25 * 1.73205;
    return maximumRayHitTime + voxelDiagonalWidth;
  }
  
  bool exceededAOTime(float maximumHitTime) {
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
  device uint *smallCellOffsets;
  device uint *smallAtomReferences;
  device float4 *convertedAtoms;
  
  
  
  __attribute__((__always_inline__))
  IntersectionResult intersect(IntersectionQuery intersectionQuery) {
    bool continueLoop;
    const DDA dda(intersectionQuery.rayOrigin,
                  intersectionQuery.rayDirection,
                  bvhArgs,
                  &continueLoop);
    float voxelMaximumTime;
    ushort3 progress = ushort3(0);
    
    IntersectionResult result;
    result.accept = false;
    result.atomID = 0;
    result.distance = 1e38;
    
    while (continueLoop) {
      // Search for the next occupied voxel.
      uint smallCellOffset = 0;
      while (true) {
        ushort3 gridDims = bvhArgs->smallVoxelCount;
        ushort3 cellCoordinates = dda.cellCoordinates(progress, gridDims);
        uint cellAddress = VoxelAddress::generate(gridDims, cellCoordinates);
        smallCellOffset = smallCellOffsets[cellAddress];
        
        voxelMaximumTime = dda.voxelMaximumTime(progress);
        progress = dda.increment(progress);
        continueLoop = dda.continueLoop(progress, gridDims);
        
        float maximumHitTime = dda.maximumHitTime(voxelMaximumTime);
        if (intersectionQuery.exceededAOTime(maximumHitTime)) {
          continueLoop = false;
        }
        
        // WARNING: An infinite loop may occur here.
        if (smallCellOffset > 0 || !continueLoop) {
          break;
        }
      }
      
      float maximumHitTime = dda.maximumHitTime(voxelMaximumTime);
      if (intersectionQuery.exceededAOTime(maximumHitTime)) {
        continueLoop = false;
      } else {
        result.distance = maximumHitTime;
        
        // Manually specifying the loop structure, to prevent the compiler
        // from unrolling it.
        ushort i = 0;
        while (true) {
          // Locate the atom.
          uint reference = smallAtomReferences[smallCellOffset + i];
          if (reference == 0) {
            break;
          }
          
          // Run the intersection test.
          float4 atom = convertedAtoms[reference];
          {
            float3 oc = intersectionQuery.rayOrigin - atom.xyz;
            float b2 = dot(oc, intersectionQuery.rayDirection);
            float c = fma(oc.x, oc.x, -atom.w * atom.w);
            c = fma(oc.y, oc.y, c);
            c = fma(oc.z, oc.z, c);
            
            float disc4 = b2 * b2 - c;
            if (disc4 > 0) {
              float distance = fma(-disc4, rsqrt(disc4), -b2);
              if (distance >= 0 && distance < result.distance) {
                result.distance = distance;
                result.atomID = reference;
              }
            }
          }
          
          // Prevent corrupted memory from causing an infinite loop. We'll
          // revisit this later, as the check probably harms performance.
          i += 1;
          if (i >= 64) {
            break;
          }
        }
        if (result.distance < maximumHitTime) {
          result.accept = true;
          continueLoop = false;
        }
      }
    }
    
    if (!result.accept) {
      result.atomID = 0;
    }
    return result;
  }
};

#endif // RAY_TRAVERSAL_H
