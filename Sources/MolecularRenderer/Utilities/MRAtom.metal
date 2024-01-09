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
MRAtomStyle {
  // Color in RGB color space.
  packed_half3 color;

  // Radius in nm. We don't know the actual radius to 11 bits of precision, so
  // Float16 is fine.
  half radius;
};

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
  
  // Flags to modify how the atom is rendered.
  ushort tailStorage;
  
  // Atomic number.
  uchar get_element() {
    return tailStorage % 128;
  }
  
  MRAtom() {
    
  }
  
  // Bypass an issue where the Metal compiler doesn't actually align the read.
  MRAtom(const device MRAtom* address) {
    float4 data = *(const device float4*)address;
    this->origin = data.xyz;
    this->radiusSquared = as_type<half2>(data.w)[0];
    this->tailStorage = as_type<ushort2>(data.w)[1];
  }
  
  void store(device MRAtom* address) {
    float4 data {
      origin.x,
      origin.y,
      origin.z,
      as_type<float>(half2(radiusSquared, as_type<half>(tailStorage)))
    };
    *((device float4*)address) = data;
  }
  
  MRAtom(float3 origin,
         half radius,
         uchar element,
         uchar flags = 0)
  {
    this->origin = origin;
    this->radiusSquared = radius * radius;
    this->tailStorage = as_type<ushort>(uchar2(element, flags));
  }
  
  MRAtom(float3 origin,
         ushort tailStorage)
  {
    this->origin = origin;
    this->tailStorage = tailStorage;
  }
  
  MRAtom(float3 origin,
         half radiusSquared,
         ushort tailStorage)
  {
    this->origin = origin;
    this->radiusSquared = radiusSquared;
    this->tailStorage = tailStorage;
  }
  
  half getRadius(const device MRAtomStyle* styles) {
    auto styles_ptr = (device half4*)(styles + get_element());
    return styles_ptr[0].w;
  }
  
  half3 getColor(const device MRAtomStyle* styles) {
    auto styles_ptr = (device half4*)(styles + get_element());
    return styles_ptr[0].xyz;
  }
  
  MRBoundingBox getBoundingBox(const device MRAtomStyle* styles) {
    half radius = this->getRadius(styles);
    auto min = origin - float(radius);
    auto max = origin + float(radius);
    return MRBoundingBox {
      packed_float3(min),
      packed_float3(max)
    };
  }
  
  ushort hash() const {
    uint3 upper12(as_type<uint>(origin.x),
                  as_type<uint>(origin.y),
                  as_type<uint>(origin.z));
    uint hash32 = upper12[0] ^ upper12[1] ^ upper12[2];
    
    // Breaks commutativity among elements of the vector.
    constexpr float multiplier_1 = 2.548385;
    constexpr float multiplier_2 = 3.379348;
    float fhash = fma(origin.y, multiplier_2, origin.z);
    fhash = fma(origin.x, multiplier_1, fhash);
    hash32 *= as_type<uint>(fhash);
    
    ushort2 halves = as_type<ushort2>(hash32);
    ushort hash16 = halves[0] ^ halves[1];
    
    // If two elements have the same radius, we can theoretically overwrite the
    // previous buffer in-place. No need to factor atomic number into the hash.
    ushort upper2 = as_type<ushort>(radiusSquared);
    hash32 = uint(hash16 * upper2);
    halves = as_type<ushort2>(hash32);
    return halves[1];
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
