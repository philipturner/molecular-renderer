//
//  Ray.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/8/23.
//

#ifndef RAY_H
#define RAY_H

#include <metal_stdlib>
using namespace metal;

template <typename T>
struct Ray {
  float3 origin;
  vec<T, 3> direction;
};

#endif // RAY_H
