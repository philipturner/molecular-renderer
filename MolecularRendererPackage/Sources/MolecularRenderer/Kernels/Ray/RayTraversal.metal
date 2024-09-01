//
//  RayTraversal.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/14/23.
//

#ifndef RAY_TRAVERSAL_H
#define RAY_TRAVERSAL_H

#include <metal_stdlib>
#include "../Ray/DDA.metal"
#include "../Ray/Ray.metal"
#include "../Utilities/Constants.metal"
using namespace metal;

// MARK: - Old Data Structures

struct IntersectionResult {
  bool accept;
  uint atomID;
  float distance;
};

struct IntersectionParams {
  bool isAORay;
  float maxRayHitTime;
};

// MARK: - New Data Structures

struct BVHDescriptor {
  constant BVHArguments *bvhArgs;
  device uint4 *largeCellMetadata;
  device uint *smallCellOffsets;
  device uint *smallAtomReferences;
  device float4 *convertedAtoms;
};

struct IntersectionQuery {
  float3 rayOrigin;
  float3 rayDirection;
  IntersectionParams params;
};

// MARK: - Intersector Class

class RayIntersector {
public:
  METAL_FUNC
  static void intersect(thread IntersectionResult *result,
                        float3 rayOrigin,
                        float3 rayDirection,
                        float4 atom,
                        uint atomID)
  {
    // Do not walk inside an atom; doing so will produce corrupted graphics.
    float3 oc = rayOrigin - atom.xyz;
    float b2 = dot(oc, rayDirection);
    float c = fma(oc.x, oc.x, -atom.w * atom.w);
    c = fma(oc.y, oc.y, c);
    c = fma(oc.z, oc.z, c);
    
    float disc4 = b2 * b2 - c;
    if (disc4 > 0) {
      // If the ray hit the sphere, compute the intersection distance.
      float distance = fma(-disc4, rsqrt(disc4), -b2);
      
      // The intersection function must also check whether the intersection
      // distance is within the acceptable range. Intersection functions do not
      // run in any particular order, so the maximum distance may be different
      // from the one passed into the ray intersector.
      if (distance >= 0 && distance < result->distance) {
        result->distance = distance;
        result->atomID = atomID;
      }
    }
  }
  
  METAL_FUNC
  static IntersectionResult traverse(BVHDescriptor bvhDescriptor,
                                     IntersectionQuery intersectionQuery)
  {
    DDA dda(intersectionQuery.rayOrigin,
            intersectionQuery.rayDirection,
            bvhDescriptor.bvhArgs);
    
    IntersectionResult result;
    result.accept = false;
    result.atomID = 0;
    result.distance = MAXFLOAT;
    
    float maxTargetDistance;
    if (intersectionQuery.params.isAORay) {
      constexpr float voxelDiagonalWidth = 0.25 * 1.73205;
      float maxRayHitTime = intersectionQuery.params.maxRayHitTime;
      maxTargetDistance = maxRayHitTime + voxelDiagonalWidth;
    }
    
    while (dda.continue_loop) {
      // To reduce divergence, fast forward through empty voxels.
      uint smallCellOffset = 0;
      bool continue_fast_forward = true;
      while (continue_fast_forward) {
        uint address = dda.createAddress();
        smallCellOffset = bvhDescriptor.smallCellOffsets[address];
        dda.incrementPosition();
        
        float target_distance = dda.get_max_accepted_t();
        if (intersectionQuery.params.isAORay &&
            target_distance > maxTargetDistance) {
          dda.continue_loop = false;
        }
        
        if (smallCellOffset == 0) {
          continue_fast_forward = dda.continue_loop;
        } else {
          continue_fast_forward = false;
        }
      }
      
      float target_distance = dda.get_max_accepted_t();
      if (intersectionQuery.params.isAORay &&
          target_distance > maxTargetDistance) {
        dda.continue_loop = false;
      } else {
        result.distance = target_distance;
        
        // Manually specifying the loop structure, to prevent the compiler
        // from unrolling it.
        ushort i = 0;
        while (true) {
          // Locate the atom.
          auto references = bvhDescriptor.smallAtomReferences;
          uint reference = references[smallCellOffset + i];
          if (reference == 0) {
            break;
          }
          
          // Run the intersection test.
          float4 atom = bvhDescriptor.convertedAtoms[reference];
          RayIntersector::intersect(&result,
                                    intersectionQuery.rayOrigin,
                                    intersectionQuery.rayDirection,
                                    atom,
                                    reference);
          
          // Prevent corrupted memory from causing an infinite loop. We'll
          // revisit this later, as the check probably harms performance.
          i += 1;
          if (i >= 64) {
            break;
          }
        }
        if (result.distance < target_distance) {
          result.accept = true;
          dda.continue_loop = false;
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
