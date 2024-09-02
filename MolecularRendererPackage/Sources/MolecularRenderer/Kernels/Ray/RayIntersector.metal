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
  ushort3 tgid;
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
  device uint *smallCellOffsets;
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
      float voxelMaximumTime;
      uint readOffset;
      ushort3 tgid;
      
      // Search for the next occupied voxel.
      while (true) {
        // Save the state for the current counter.
        {
          ushort3 gridDims = bvhArgs->smallVoxelCount;
          ushort3 cellCoordinates = dda.cellCoordinates(progress, gridDims);
          uint address = VoxelAddress::generate(gridDims, cellCoordinates);
          
          voxelMaximumTime = dda.voxelMaximumTime(progress);
          readOffset = smallCellOffsets[address];
          tgid = cellCoordinates / 8;
        }
        
        // Increment the counter.
        progress = dda.increment(progress);
        
        // Exit the inner loop.
        if (!dda.continueLoop(progress, bvhArgs->smallVoxelCount)) {
          break;
        }
        if (intersectionQuery.exceededAOTime(dda, voxelMaximumTime)) {
          break;
        }
        if (readOffset > 0) {
          break;
        }
      }
      
      // Exit the outer loop.
      if (!dda.continueLoop(progress, bvhArgs->smallVoxelCount)) {
        break;
      }
      if (intersectionQuery.exceededAOTime(dda, voxelMaximumTime)) {
        break;
      }
      
      // Don't let empty voxels affect the result.
      if (readOffset == 0) {
        continue;
      }
      
      // Retrieve the large voxel's lower corner.
      float3 lowerCorner = bvhArgs->worldMinimum;
      lowerCorner += float3(tgid) * 2;
      
      // Retrieve the large voxel's metadata.
      uint4 metadata;
      {
        ushort3 cellCoordinates = ushort3(lowerCorner + 64);
        cellCoordinates /= 2;
        ushort3 gridDims = ushort3(64);
        uint address = VoxelAddress::generate(gridDims, cellCoordinates);
        metadata = largeCellMetadata[address];
      }
      
      // Set the distance register to the maximum hit time.
      result.distance = dda.maximumHitTime(voxelMaximumTime);
      
      // Manually specifying the loop structure, to prevent the compiler
      // from unrolling it.
      ushort i = 0;
      while (true) {
        // Locate the atom.
        uint referenceID = readOffset + i;
        ushort reference = smallAtomReferences[referenceID];
        if (reference == 0) {
          break;
        }
        
        // Retrieve the atom.
        uint atomID = metadata[1] + reference;
        float4 atom = float4(convertedAtoms[atomID]);
        atom.xyz += lowerCorner;
        
        // Run the intersection test.
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
              result.atomID = atomID;
              result.distance = distance;
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
      
      // Check whether we found a hit.
      if (result.distance < dda.maximumHitTime(voxelMaximumTime)) {
        result.accept = true;
        result.tgid = tgid;
      }
    }
    
    return result;
  }
};

#endif // RAY_TRAVERSAL_H
