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

struct _IntersectionResult {
  float distance;
  bool accept;
  uint atom;
};

struct IntersectionResult {
  float distance;
  bool accept;
  float4 newAtom;
  uint reference;
};

struct IntersectionParams {
  bool isAORay;
  float maxRayHitTime;
  bool isShadowRay;
  
  bool get_has_max_time() const {
    return isAORay || isShadowRay;
  }
};

// MARK: - New Data Structures

struct BVHDescriptor {
  constant BVHArguments *bvhArgs;
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
  static void intersect(thread _IntersectionResult *result,
                        float3 rayOrigin,
                        float3 rayDirection,
                        float4 atom,
                        uint reference)
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
        result->atom = reference;
      }
    }
  }
  
  METAL_FUNC
  static IntersectionResult traverse(BVHDescriptor bvh,
                                     IntersectionQuery intersectionQuery)
  {
    DDA dda(intersectionQuery.rayOrigin,
            intersectionQuery.rayDirection,
            bvh.bvhArgs);
    _IntersectionResult result { MAXFLOAT, false };
    
    float maxTargetDistance;
    if (intersectionQuery.params.get_has_max_time()) {
      constexpr float voxel_size = 0.25;
      float maxRayHitTime = intersectionQuery.params.maxRayHitTime;
      maxTargetDistance = maxRayHitTime + sqrt(float(3)) * voxel_size;
    }
    
    while (dda.continue_loop) {
      // To reduce divergence, fast forward through empty voxels.
      uint smallCellOffset = 0;
      bool continue_fast_forward = true;
      while (continue_fast_forward) {
        smallCellOffset = bvh.smallCellOffsets[dda.address];
        dda.increment_position();
        
        float target_distance = dda.get_max_accepted_t();
        if (intersectionQuery.params.get_has_max_time() &&
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
      if (intersectionQuery.params.get_has_max_time() &&
          target_distance > maxTargetDistance) {
        dda.continue_loop = false;
      } else {
        if (intersectionQuery.params.isShadowRay) {
          float maxRayHitTime = intersectionQuery.params.maxRayHitTime;
          target_distance = min(target_distance, maxRayHitTime);
        }
        result.distance = target_distance;
        
        // Manually specifying the loop structure, to prevent the compiler
        // from unrolling it.
        ushort i = 0;
        while (true) {
          // Locate the atom.
          uint reference = bvh.smallAtomReferences[smallCellOffset + i];
          if (reference == 0) {
            break;
          }
          
          // Run the intersection test.
          float4 atom = bvh.convertedAtoms[reference];
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
    
    IntersectionResult out { result.distance, result.accept };
    if (out.accept) {
      out.newAtom = bvh.convertedAtoms[result.atom];
      out.reference = result.atom;
    }
    return out;
  }
};

#endif // RAY_TRAVERSAL_H
