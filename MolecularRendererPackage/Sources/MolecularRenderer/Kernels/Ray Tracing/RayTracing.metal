//
//  RayTracing.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/14/23.
//

#ifndef RAY_TRACING_H
#define RAY_TRACING_H

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "Ray.metal"
#include "../Uniform Grids/DDA.metal"
using namespace metal;

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

class RayIntersector {
public:
  template <typename T>
  METAL_FUNC static void intersect
  (
   thread _IntersectionResult *result,
   Ray<T> ray,
   float4 newAtom,
   uint reference)
  {
    // Do not walk inside an atom; doing so will produce corrupted graphics.
    float3 oc = ray.origin - newAtom.xyz;
    float b2 = dot(oc, float3(ray.direction));
    float c = fma(oc.x, oc.x, -newAtom.w * newAtom.w);
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
  
  template <typename T>
  METAL_FUNC static IntersectionResult traverse
  (
   Ray<T> ray, DenseGrid grid, IntersectionParams params)
  {
    DenseDDA<T> dda(ray, grid.bvhArgs);
    _IntersectionResult result { MAXFLOAT, false };
    
    float maxTargetDistance;
    if (params.get_has_max_time()) {
      const float voxel_size = 0.25;
      maxTargetDistance = params.maxRayHitTime + sqrt(float(3)) * voxel_size;
    }
    
    while (dda.continue_loop) {
      // To reduce divergence, fast forward through empty voxels.
      uint voxel_data = 0;
      bool continue_fast_forward = true;
      while (continue_fast_forward) {
        voxel_data = grid.data[dda.address];
        dda.increment_position();
        
        float target_distance = dda.get_max_accepted_t();
        if (params.get_has_max_time() && target_distance > maxTargetDistance) {
          dda.continue_loop = false;
        }
        
        uint voxel_count = voxel_data & voxel_count_mask;
        if (voxel_count == 0) {
          continue_fast_forward = dda.continue_loop;
        } else {
          continue_fast_forward = false;
        }
      }
      
      float target_distance = dda.get_max_accepted_t();
      if (params.get_has_max_time() && target_distance > maxTargetDistance) {
        dda.continue_loop = false;
      } else {
        if (params.isShadowRay) {
          target_distance = min(target_distance, params.maxRayHitTime);
        }
        result.distance = target_distance;
        
        uint count = reverse_bits(voxel_data & voxel_count_mask);
        uint offset = voxel_data & voxel_offset_mask;
        uint upper_bound = offset + count;
        for (; offset < upper_bound; ++offset) {
          uint reference = grid.references[offset];
          float4 newAtom = grid.newAtoms[reference];
          RayIntersector::intersect(&result, ray, newAtom, reference);
        }
        if (result.distance < target_distance) {
          result.accept = true;
          dda.continue_loop = false;
        }
      }
    }
    
    IntersectionResult out { result.distance, result.accept };
    if (out.accept) {
      out.newAtom = grid.newAtoms[result.atom];
      out.reference = result.atom;
    }
    return out;
  }
};

#endif
