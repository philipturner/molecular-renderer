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

template <typename REFERENCE>
struct _IntersectionResult {
  float distance;
  bool accept;
  REFERENCE atom;
};

struct IntersectionResult {
  float distance;
  bool accept;
  MRAtom atom;
};

struct IntersectionParams {
  bool isAORay;
  float maxRayHitTime;
  bool isShadowRay;
  
  bool get_has_max_time() const {
    return isAORay || isShadowRay;
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
