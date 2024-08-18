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
#include "../Utilities/MRAtom.metal"
#include "Ray.metal"
#include "../Uniform Grids/UniformGrid.metal"
using namespace metal;

struct _IntersectionResult {
  float distance;
  bool accept;
  uint atom;
};

struct IntersectionResult {
  float distance;
  bool accept;
  MRAtom atom;
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
   float4 sphere,
   uint reference)
  {
    // Do not walk inside an atom; doing so will produce corrupted graphics.
    float3 oc = ray.origin - sphere.xyz;
    float b2 = dot(oc, float3(ray.direction));
    float c = fma(oc.x, oc.x, float(-as_type<half2>(sphere.w)[0]));
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
    DenseDDA<T> dda(ray, grid.dims);
    _IntersectionResult result { MAXFLOAT, false };
    
    float maxTargetDistance;
    if (params.get_has_max_time()) {
      const float voxel_size = voxel_width_numer / voxel_width_denom;
      maxTargetDistance = params.maxRayHitTime + sqrt(float(3)) * voxel_size;
    }
    
    while (dda.continue_loop) {
      // To reduce divergence, fast forward through empty voxels.
      VOXEL_DATA voxel_data = 0;
      bool continue_fast_forward = true;
      while (continue_fast_forward) {
        voxel_data = grid.data[dda.address];
        dda.increment_position();
        
        float target_distance = dda.get_max_accepted_t();
        if (params.get_has_max_time() && target_distance > maxTargetDistance) {
          dda.continue_loop = false;
        }
        
#if SCENE_SIZE_EXTREME
        uint voxel_count = voxel_data[0];
#else
        uint voxel_count = voxel_data & voxel_count_mask;
#endif
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
        
#if SCENE_SIZE_EXTREME
        uint count = voxel_data[0] & 0xFF;
        uint offset = voxel_data[1];
#else
        uint count = reverse_bits(voxel_data & voxel_count_mask);
        uint offset = voxel_data & voxel_offset_mask;
#endif
        uint upper_bound = offset + count;
        for (; offset < upper_bound; ++offset) {
          uint reference = grid.references[offset];
          float4 sphere = ((device float4*)grid.atoms)[reference];
          RayIntersector::intersect(&result, ray, sphere, reference);
        }
        if (result.distance < target_distance) {
          result.accept = true;
          dda.continue_loop = false;
        }
      }
    }
    
    IntersectionResult out { result.distance, result.accept };
    if (out.accept) {
      out.atom = MRAtom(grid.atoms + result.atom);
      out.reference = result.atom;
    }
    return out;
  }
};


#if 0

namespace old_sparse_grids_draft {
  // TODO: In the new draft, don't require camera position and cutoff distance
  // to be part of params.
  template <typename T>
  METAL_FUNC static IntersectionResult traverse
  (
   Ray<T> ray, SparseGrid grid, IntersectionParams params)
  {
    ray = ray.get_sparse_ray();
    bool is_high_res = false;
    if (params.isAORay) {
      is_high_res = ray.get_is_high_res();
    }
    
    SparseDDA<T> dda(ray, grid, is_high_res);
    _IntersectionResult<ushort> result { MAXFLOAT, false };
    uint atom_offset = 0;
    
    float maxTargetDistance;
    if (params.get_has_max_time()) {
      float scale = float(dda.lower_width) / 4;
      maxTargetDistance = params.maxRayHitTime * scale + sqrt(float(3));
    }
    
    while (dda.continue_upper_loop) {
      dda.start_upper_iteration();
      if (!dda.continue_upper_loop) {
        break;
      }
      while (dda.continue_lower_loop) {
        bool previous_continue_lower = dda.continue_lower_loop;
        while (dda.cursor == dda.loop_end) {
          previous_continue_lower = dda.continue_lower_loop;
          if (!dda.upper_voxel_empty) {
            dda.start_lower_iteration();
          }
          dda.increment_position();
          if (!dda.continue_lower_loop) {
            break;
          }
        }
        
        float target_distance = dda.get_max_accepted_t();
        if (params.get_has_max_time() && target_distance > maxTargetDistance) {
          previous_continue_lower = false;
        }
        if (previous_continue_lower) {
          for (; dda.cursor < dda.loop_end; ++dda.cursor) {
            auto reference = dda.references[dda.cursor];
            float4 sphere = ((device float4*)dda.atoms)[reference];
            RayIntersector::intersect(&result, ray, sphere, reference);
          }
          if (result.distance < target_distance) {
            result.accept = true;
            atom_offset = dda.upper_id * 16384;
            dda.continue_lower_loop = false;
            dda.continue_upper_loop = false;
          }
        }
      }
    }
    
    IntersectionResult out { result.distance, result.accept };
    if (out.accept) {
      float scale = 4 / float(dda.lower_width);
      out.distance *= scale;
      
      uint atom_id = atom_offset + result.atom;
      out.atom = MRAtom(grid.upper_voxel_atoms + atom_id);
      out.atom.origin *= 4 * scale;
      out.atom.radiusSquared = 0;
    }
    return out;
  }
};

#endif

#endif
