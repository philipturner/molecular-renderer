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

class RayIntersector {
public:
  template <typename T>
  static void intersect
  (
   thread _IntersectionResult *result,
   Ray<T> ray,
   float4 sphere,
   REFERENCE reference)
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
};

#endif
