//
//  AtomStatistics.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

#ifndef ATOM_STATISTICS_H
#define ATOM_STATISTICS_H

#include <metal_stdlib>
using namespace metal;

struct __attribute__((aligned(8)))
MRBoundingBox {
  packed_float3 min;
  packed_float3 max;
};

struct __attribute__((aligned(16)))
MRAtom {
  // Position in nm.
  packed_float3 origin;
  
  // Radius in nm.
  half radiusSquared;
  
  // Atomic number.
  ushort element;
  
  MRAtom() {
    
  }
  
  // Bypass an issue where the Metal compiler doesn't actually align the read.
  MRAtom(const device MRAtom* address) {
    float4 data = *(const device float4*)address;
    this->origin = data.xyz;
    this->radiusSquared = as_type<half2>(data.w)[0];
    this->element = as_type<ushort2>(data.w)[1];
  }
  
  void store(device MRAtom* address) {
    float4 data {
      origin.x,
      origin.y,
      origin.z,
      as_type<float>(half2(radiusSquared, as_type<half>(element)))
    };
    *((device float4*)address) = data;
  }
  
  half3 getColor(const device half4* styles) {
    return styles[element].xyz;
  }
    
  half getRadius(const device half4* styles) {
    return styles[element].w;
  }
  
  MRBoundingBox getBoundingBox(const device half4* styles) {
    half radius = this->getRadius(styles);
    auto min = origin - float(radius);
    auto max = origin + float(radius);
    return MRBoundingBox {
      packed_float3(min),
      packed_float3(max)
    };
  }
};

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
