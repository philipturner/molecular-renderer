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
#include "Atom.metal"
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
};

#endif
