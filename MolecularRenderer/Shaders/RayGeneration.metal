//
//  RayGeneration.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/22/23.
//

#include <metal_stdlib>
#include "RayTracing.metal"
#include "Sampling.metal"
using namespace metal;
using namespace raytracing;

// Partially sourced from:
// https://github.com/nvpro-samples/gl_vk_raytrace_interop/blob/master/shaders/raygen.rgen\

// Better implementation at:
// https://github.com/microsoft/DirectX-Graphics-Samples/tree/master/Samples/Desktop/D3D12Raytracing/src/D3D12RaytracingRealTimeDenoisedAmbientOcclusion/RTAO

// TODO: Try using Metal function calls instead of ray query; perhaps it will
// sort rays and avoid the 2.5x divergence.

constant int rtao_samples = 4; // 64
constant float rtao_radius = 0.5; // 5.0
constant float rtao_power = 2.0;

#define EPS 0.05
constant float PI = 3.141592653589;

// Use C++ class to bypass AIR symbol duplication error.
class RayGeneration {
public:
  static void compute_default_basis
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
  
  static float queryOcclusion
   (
    float3 intersectionPoint, Atom atom, ushort2 pixelCoords, uint frameNumber,
    primitive_acceleration_structure accelerationStructure)
  {
    float3 position = intersectionPoint;
    float3 normal = normalize(intersectionPoint - atom.origin);
    
    // Move origin slightly away from the surface to avoid self-occlusion.
    float3 origin = position + normal * float(0.01);
    
    float3 x, y, z;
    float occlusion = 0.0;
    compute_default_basis(normal, x, y, z);
    
    uint seed = Sampling::tea(as_type<uint>(pixelCoords), frameNumber);
    
    for (int i = 0; i < rtao_samples; ++i) {
      float r1 = Sampling::radinv2(seed);
      float r2 = Sampling::radinv_fl(seed, 3);
      float sq = sqrt(1.0 - r2);
      
      float3 direction(cos(2 * PI * r1) * sq, sin(2 * PI * r1) * sq, sqrt(r2));
      direction      = direction.x * x + direction.y * y + direction.z * z;
      seed++;
      
      ray ray;
      ray.origin = origin;
      ray.direction = direction;
      ray.max_distance = rtao_radius;
      auto intersection = RayTracing::traverseAccelerationStructure
       (
        ray, accelerationStructure);
      
      occlusion += intersection.accept ? 1.0 : 0.0;
    }
    
    occlusion = 1 - (occlusion / float(rtao_samples));
    occlusion = pow(clamp(occlusion, float(0), float(1)), rtao_power);
    return occlusion;
  }
};

