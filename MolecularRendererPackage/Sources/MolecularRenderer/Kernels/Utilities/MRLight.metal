//
//  MRLight.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

#ifndef MR_LIGHT_H
#define MR_LIGHT_H

#include <metal_stdlib>
using namespace metal;

struct __attribute__((aligned(16)))
MRLight {
  // Position in nm.
  packed_float3 origin;
  
  // Parameters for Blinn-Phong shading, typically 1.
  half diffusePower;
  half specularPower;
  
  // Bypass an issue where the Metal compiler doesn't actually align the read.
  MRLight(device MRLight* address) {
    float4 data = *(device float4*)address;
    this->origin = data.xyz;
    this->diffusePower = as_type<half2>(data.w)[0];
    this->specularPower = as_type<half2>(data.w)[1];
  }
};

#endif
