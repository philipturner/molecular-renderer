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



#endif
