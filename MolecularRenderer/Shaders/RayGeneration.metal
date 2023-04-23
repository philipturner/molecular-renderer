//
//  RayGeneration.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/22/23.
//

#include <metal_stdlib>
using namespace metal;

// Partially sourced from:
// https://github.com/nvpro-samples/gl_vk_raytrace_interop/blob/master/shaders/raygen.rgen

constant int rtao_samples = 2; // 64
constant float rtao_radius = 5.0;
constant float rtao_power = 2.0;

//////////////////////////// AO //////////////////////////////////////
#define EPS 0.05
constant float PI = 3.141592653589;

void compute_default_basis
 (
  const float3 normal, thread float3 &x, thread float3 &y, thread float3 &z)
{
  // ZAP's default coordinate system for compatibility
  z              = normal;
  const float yz = -z.y * z.z;
  y = normalize
  (
   (abs(z.z) > 0.99999f)
   ? float3(-z.x * z.y, 1.0f - z.y * z.y, yz)
   : float3(-z.x * z.z, yz, 1.0f - z.z * z.z));
  
  x = cross(y, z);
}

