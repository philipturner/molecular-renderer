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
  device ushort *smallAtomReferences;
  device half4 *convertedAtoms;
  
  IntersectionResult intersect(IntersectionQuery intersectionQuery) {
    bool executeFutureIteration;
    const DDA dda(intersectionQuery.rayOrigin,
                  intersectionQuery.rayDirection,
                  bvhArgs,
                  &executeFutureIteration);
    ushort3 progress = ushort3(0);
    
    IntersectionResult result;
    result.accept = false;
    result.atomID = 0;
    result.distance = 1e38;
    
    while (executeFutureIteration) {
      float voxelMaximumTime;
      ushort3 smallCellCoordinates;
      
      // Search for the next occupied voxel.
      while (true) {
        // Save the state for the current counter.
        {
          ushort3 gridDims = bvhArgs->smallVoxelCount;
          smallCellCoordinates = dda.cellCoordinates(progress, gridDims);
          voxelMaximumTime = dda.voxelMaximumTime(progress);
        }
        
        // Change the counter to a different value.
        progress = dda.increment(progress);
        
        // Break out of the inner loop, if the next cell will be out of bounds.
        {
          ushort3 gridDims = bvhArgs->smallVoxelCount;
          executeFutureIteration = dda.continueLoop(progress, gridDims);
        }
        
        // Return if out of range.
        float maximumHitTime = dda.maximumHitTime(voxelMaximumTime);
        if (intersectionQuery.exceededAOTime(maximumHitTime)) {
          break;
        }
        
        // Materialize the small-cell offset.
        uint readOffset;
        {
          ushort3 cellCoordinates = smallCellCoordinates;
          ushort3 gridDims = bvhArgs->smallVoxelCount;
          uint address = VoxelAddress::generate(gridDims, cellCoordinates);
          readOffset = smallCellOffsets[address];
        }
        
        // Break out of the loop.
        if (readOffset > 0 || !executeFutureIteration) {
          break;
        }
      }
      
      // Return early if out of range.
      float maximumHitTime = dda.maximumHitTime(voxelMaximumTime);
      if (intersectionQuery.exceededAOTime(maximumHitTime)) {
        executeFutureIteration = false;
        continue;
      }
      
      // Materialize the small-cell offset.
      uint readOffset;
      {
        ushort3 cellCoordinates = smallCellCoordinates;
        ushort3 gridDims = bvhArgs->smallVoxelCount;
        uint address = VoxelAddress::generate(gridDims, cellCoordinates);
        readOffset = smallCellOffsets[address];
      }
      
      if (readOffset == 0) {
        // Don't do anything if the voxel has no contents.
      } else {
        result.distance = maximumHitTime;
        
        // Retrieve the large voxel's lower corner.
        ushort3 tgid = smallCellCoordinates / 8;
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
          uint atomID = metadata[1] + reference;
          
          // Retrieve the atom.
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
                result.tgid = tgid;
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
        
        // Return if we found a hit.
        if (result.distance < maximumHitTime) {
          result.accept = true;
          executeFutureIteration = false;
        }
      }
    }
    
    if (!result.accept) {
      result.atomID = 0;
      result.tgid = 0;
    }
    return result;
  }
};

#endif // RAY_TRAVERSAL_H
