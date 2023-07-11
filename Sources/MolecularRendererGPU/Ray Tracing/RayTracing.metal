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

struct IntersectionResult {
  float distance;
  bool accept;
  MRAtom atom;
};

struct IntersectionParams {
  bool isAORay;
  float maxRayHitTime;
  bool isShadowRay;
};

class RayTracing {
public:
  static IntersectionResult traverseDenseGrid
  (
   Ray ray, DenseGrid grid, IntersectionParams params)
  {
    DifferentialAnalyzer dda(ray, grid);
    IntersectionResult result { MAXFLOAT, false };
    ushort result_atom;
    
    if (params.isAORay) {
      const float voxel_size = voxel_width_numer / voxel_width_denom;
      params.maxRayHitTime += sqrt(float(3)) * voxel_size;
    }
    
  #if FAULT_COUNTERS_ENABLE
    int fault_counter1 = 0;
  #endif
    while (dda.continue_loop) {
      // To reduce divergence, fast forward through empty voxels.
      uint voxel_data = 0;
      bool continue_fast_forward = true;
      while (continue_fast_forward) {
#if FAULT_COUNTERS_ENABLE
        fault_counter1 += 1; if (fault_counter1 > 100) { return { MAXFLOAT, false }; }
#endif
        voxel_data = grid.data[dda.address];
        dda.increment_position();
        
        if ((voxel_data & voxel_count_mask) == 0) {
          continue_fast_forward = dda.continue_loop;
        } else {
          continue_fast_forward = false;
        }
      }
      
      uint count = reverse_bits(voxel_data & voxel_count_mask);
      uint offset = voxel_data & voxel_offset_mask;
      
      float target_distance = dda.get_max_accepted_t();
      if (params.isAORay && target_distance > params.maxRayHitTime) {
        dda.continue_loop = false;
      } else {
        result.distance = target_distance;
        
#if FAULT_COUNTERS_ENABLE
        int fault_counter2 = 0;
#endif
        for (ushort i = 0; i < count; ++i) {
#if FAULT_COUNTERS_ENABLE
          fault_counter2 += 1; if (fault_counter2 > 300) { return { MAXFLOAT, false }; }
#endif
          ushort reference = grid.references[offset + i];
          float4 data = ((device float4*)grid.atoms)[reference];
          
          // Do not walk inside an atom; doing so will produce corrupted graphics.
          float3 oc = ray.origin - data.xyz;
          float b2 = dot(oc, ray.direction);
          float c = dot(oc, oc) - as_type<half2>(data.w)[0];
          float disc4 = b2 * b2 - c;
          
          if (disc4 > 0) {
            // If the ray hit the sphere, compute the intersection distance.
            float distance = -b2 - sqrt(disc4);
            
            // The intersection function must also check whether the intersection
            // distance is within the acceptable range. Intersection functions do not
            // run in any particular order, so the maximum distance may be different
            // from the one passed into the ray intersector.
            if (distance >= 0 && distance < result.distance) {
              result.distance = distance;
              result_atom = reference;
            }
          }
        }
        if (result.distance < target_distance || params.isShadowRay) {
          result.accept = true;
          dda.continue_loop = false;
        }
      }
    }
    
    if (result.accept) {
      result.atom = MRAtom(grid.atoms + result_atom);
    }
    return result;
  }
};

#endif
