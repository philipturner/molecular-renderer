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
  
  Ray get_sparse_ray() const {
    Ray out = *this;
    out.origin /= 4;
    return out;
  }
  
  bool get_is_high_res(/*camera position, cutoff*/) const {
    return false;
  }
};

#endif
