//
//  RayTracing.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/14/23.
//

#ifndef RAY_TRACING_H
#define RAY_TRACING_H

#include <metal_stdlib>
#include "Constants.metal"
#include "MRAtom.metal"
#include "UniformGrid.metal"
using namespace metal;
using namespace raytracing;

struct AtomIntersection {
  float distance;
  bool accept;
};

struct IntersectionResult {
  float distance;
  bool accept;
  MRAtom atom;
};

class RayTracing {
public:
  // Do not walk inside an atom; doing so will produce corrupted graphics.
  static AtomIntersection atomIntersectionFunction(ray ray, MRAtom atom) {
    float3 oc = ray.origin - atom.origin;
    float b2 = dot(oc, ray.direction);
    float c = dot(oc, oc) - atom.radiusSquared;
    float disc4 = b2 * b2 - c;
    AtomIntersection ret;
    
    if (disc4 <= 0.0f) {
      // If the ray missed the sphere, return false.
      ret.accept = false;
    }
    else {
      // Otherwise, compute the intersection distance.
      ret.distance = -b2 - sqrt(disc4);
      
      // The intersection function must also check whether the intersection
      // distance is within the acceptable range. Intersection functions do not
      // run in any particular order, so the maximum distance may be different
      // from the one passed into the ray intersector.
      ret.accept = ret.distance >= 0 && ret.distance <= MAXFLOAT;
    }
    
    return ret;
  }
  
  // Traverse the acceleration structure.
  static IntersectionResult traverse(ray ray, accel accel)
  {
    // Parameters used to configure the intersection query.
    intersection_params params;
    params.assume_geometry_type(geometry_type::bounding_box);
    params.force_opacity(forced_opacity::opaque);
    params.accept_any_intersection(false);
    params.assume_identity_transforms(true);
    
    // Create an intersection query to test for intersection between the ray and
    // the geometry in the scene.  The `intersection_query` object tracks the
    // current state of the acceleration structure traversal.
    intersection_query<> i;
    i.reset(ray, accel, params);
    
    // Otherwise, we will need to handle bounding box intersections as they are
    // found. Call `next()` in a loop until it returns `false`, indicating that
    // acceleration structure traversal is complete.
    while (i.next()) {
      // The intersection query object keeps track of the "candidate" and
      // "committed" intersections. The "committed" intersection is the current
      // closest intersection found, while the "candidate" intersection is a
      // potential intersection. Dispatch a call to the corresponding
      // intersection function to determine whether to accept the candidate
      // intersection.
      auto rawPointer = i.get_candidate_primitive_data();
      MRAtom atom = *(const device MRAtom*)rawPointer;
      
      AtomIntersection bb = atomIntersectionFunction(ray, atom);

      // Accept the candidate intersection, making it the new committed
      // intersection.
      if (bb.accept && bb.distance < i.get_committed_distance()) {
        i.commit_bounding_box_intersection(bb.distance);
      }
    }
    
    IntersectionResult intersection;
    
    // Return all the information about the committed intersection.
    auto primitive_data = i.get_committed_primitive_data();
    intersection.distance = i.get_committed_distance();
    intersection.accept =
      i.get_committed_intersection_type() == intersection_type::bounding_box;
    if (intersection.accept) {
      intersection.atom = *(const device MRAtom*)primitive_data;
    }
    
    return intersection;
  }
  
  typedef texture3d<ushort, access::read_write> uniform_grid;
  
  // Prototype of a function for uniform grid ray tracing. Instead of marking a
  // cell in the cube texture, it will eventually perform an intersection test.
  //
  // Source: https://ieeexplore.ieee.org/document/7349894
  static void traverse(ray ray, uniform_grid uniform_grid)
  {
    // The grid dimensions must be divisible by 2.
    ushort3 grid_bounds(uniform_grid.get_width(),
                        uniform_grid.get_height(),
                        uniform_grid.get_depth());
    
    float min_dt = precise::divide(1, max3(ray.direction.x,
                                           ray.direction.y,
                                           ray.direction.z));
    float grid_width = float(uniform_grid.get_width());
    
    float3 dda_position = ray.origin + float3(grid_bounds) / 2;
    half3 dda_rounded = half3(rint(dda_position));
    float3 progress = 0;
    
    uint current_mask = 0;
    uint finished_mask = as_type<uint>(ushort2(1, 1));
    while (current_mask != finished_mask) {
      uniform_grid.write(ushort4{ 1 }, ushort3(dda_rounded));
      
      float i;
      half i_r;
      float t; // change to half-precision number containing the # of steps
      float dir;
      
      ushort is_x = (progress.x < progress.y && progress.x < progress.z);
      if (is_x) {
        i = dda_position.x;
        i_r = dda_rounded.x;
        t = progress.x;
        dir = ray.direction.x;
      } else {
        i = (progress.y < progress.z) ? dda_position.y : dda_position.z;
        i_r = (progress.y < progress.z) ? dda_rounded.y : dda_rounded.z;
        t = (progress.y < progress.z) ? progress.y : progress.z;
        dir = (progress.y < progress.z) ? ray.direction.y : ray.direction.z;
      }
      
      // This is numerically unstable for very small T. At that point, the
      // direction with zero motion wouldn't generate any deltas (we can
      // effectively clamp it to zero).
      //
      // TODO: Set `progress` to FLT_MAX for such numbers, set the DDA position
      // to the center of the pixel, and mutate `ray.direction` to something
      // very small, but still processed correctly by fast math.
      float dt = fast::divide(1, abs(dir));
      i = fma(dir, min_dt, i);
      t += dt;
      
      // Eliminate this while loop because adversarial slopes cause infinite
      // iterations.
      while (abs(i - i_r) < 0.5) {
        i = fma(dir, min_dt, i);
        t += dt;
        
        // Modify a different `t_contrib` that is FMA'ed during the divergent
        // store part.
      }
      
      float i_new_rounded = rint(i);
      if (is_x) {
        dda_position.x = i;
        dda_rounded.x = half(i_new_rounded);
        progress.x = t;
      } else if (progress.y < progress.z) {
        dda_position.y = i;
        dda_rounded.y = half(i_new_rounded);
        progress.y = t;
      } else {
        dda_position.z = i;
        dda_rounded.z = half(i_new_rounded);
        progress.z = t;
      }
      
      ushort cond1 = (i_new_rounded >= 0) ? 1 : 0;
      ushort cond2 = (i_new_rounded < grid_width) ? 1 : 0;
      current_mask = as_type<uint>(ushort2(cond1, cond2));
    }
  }
};

#endif
