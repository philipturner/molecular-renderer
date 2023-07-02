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
    float3 _stop = float3(grid_bounds);
    _stop *= select(float3(0.5), float3(-0.5), ray.direction > 0);
    float3 _dt = precise::divide(1, abs(ray.direction));
    float3 _step = ray.direction / max3(abs(ray.direction.x),
                                        abs(ray.direction.y),
                                        abs(ray.direction.z));
    
    float3 dda_position = ray.origin - float3(grid_bounds) / 2;
    float3 progress = 0;
    while (true) {
      uniform_grid.write(ushort4{ 1 }, ushort3(progress));
      
      // TODO: Abstract all of the code below, as well as all of the setup, into
      // a differential_analyer class. That will let the `traverse` function be
      // inlined into the main shader for profiling.
      float i;
      float t;
      float step;
      float dt;
      float i_stop;
      if (progress.x < progress.y && progress.x < progress.z) {
        i = dda_position.x;
        t = progress.x;
        step = _step.x;
        dt = _dt.x;
        i_stop = _stop.x;
      } else {
        i = (progress.y < progress.z) ? dda_position.y : dda_position.z;
        t = (progress.y < progress.z) ? progress.y : progress.z;
        step = (progress.y < progress.z) ? _step.y : _step.z;
        dt = (progress.y < progress.z) ? _dt.y : _dt.z;
        i_stop = (progress.y < progress.z) ? _stop.y : _stop.z;
      }
      
      float i_old_rounded = rint(i);
      i += step;
      t += dt;
      float i_new_rounded = rint(i);
      while (i_new_rounded == i_old_rounded) {
        i += step;
        t += dt;
        i_new_rounded = rint(i);
      }
      
      if (progress.x < progress.y && progress.x < progress.z) {
        dda_position.x = i;
        progress.x = t;
      } else if (progress.y < progress.z) {
        dda_position.y = i;
        progress.y = t;
      } else {
        dda_position.z = i;
        progress.z = t;
      }
      if (i_new_rounded == i_stop) {
        break;
      }
    }
  }
};

#endif
