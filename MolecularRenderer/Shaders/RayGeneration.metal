//
//  RayGeneration.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/22/23.
//

#include <metal_stdlib>
#include "Constants.metal"
#include "RayTracing.metal"
#include "Sampling.metal"
using namespace metal;
using namespace raytracing;

// Partially sourced from:
// https://github.com/nvpro-samples/gl_vk_raytrace_interop/blob/master/shaders/raygen.rgen
// https://github.com/microsoft/DirectX-Graphics-Samples/tree/master/Samples/Desktop/D3D12Raytracing/src/D3D12RaytracingRealTimeDenoisedAmbientOcclusion/RTAO

constant int rtao_samples = 3; // 64
constant float rtao_radius = 0.5; // 5.0
constant float rtao_power = 2.0;

// Use C++ class to bypass AIR symbol duplication error.
class RayGeneration {
public:
  // Dispatch threadgroups across 16x16 chunks, not rounded to image size.
  // The shader will rearrange simds across 8x4 chunks, then subdivide further
  // into 2x2 (quads) and 4x4 (half-simds). The thread arrangement should
  // accelerate intersections with OpenMM tiles in supermassive acceleration
  // structures.
  static ushort2 makePixelID(ushort2 tgid, ushort2 lid) {
    // Rearrange 16x16 into a hierarchy of levels to maximize memory coalescing
    // during ray tracing:
    // - 16x16 (highest level)
    // - 16x8 (half-threadgroup)
    // - 8x8 (quarter-threadgroup)
    // - 8x4 (simd)
    // - 4x4 (half-simd)
    // - 4x2 (quarter-simd)
    // - 2x2 (quad)
    ushort local_linear_id = lid.y * 16 + lid.x;
    ushort new_y = (local_linear_id >= 128) ? 8 : 0;
    ushort new_x = (local_linear_id % 128 >= 64) ? 8 : 0;
    new_y += (local_linear_id % 64 >= 32) ? 4 : 0;
    new_x += (local_linear_id % 32 >= 16) ? 4 : 0;
    new_y += (local_linear_id % 16 >= 8) ? 2 : 0;
    new_x += (local_linear_id % 8 >= 4) ? 2 : 0;
    new_y += (local_linear_id % 4 >= 2) ? 1 : 0;
    new_x += local_linear_id % 2 >= 1;
    
    return tgid * 16 + ushort2(new_x, new_y);
  }
  
  static ray primaryRay(ushort2 pixelCoords, constant Arguments* args) {
    float3 rayDirection(float2(pixelCoords) + 0.5, -1);
    if (USE_METALFX) {
      rayDirection.xy += args->jitter;
    }
    rayDirection.xy -= float2(SCREEN_WIDTH, SCREEN_HEIGHT) / 2;
    rayDirection.y = -rayDirection.y;
    rayDirection.xy *= args->fov90SpanReciprocal;
    rayDirection = normalize(rayDirection);
    rayDirection = args->rotation * rayDirection;
    
    float3 worldOrigin = args->position;
    return { worldOrigin, rayDirection };
  }
  
  static ray secondaryRay(float3 origin, float3 direction) {
    ray ray;
    ray.origin = origin;
    ray.direction = direction;
    ray.max_distance = rtao_radius;
    return ray;
  }
  
  static float3x3 makeBasis(const float3 normal)
  {
    // ZAP's default coordinate system for compatibility
    float3 z = normal;
    const float yz = -z.y * z.z;
    float3 y = normalize
    (
     (abs(z.z) > 0.99999f)
     ? float3(-z.x * z.y, 1.0f - z.y * z.y, yz)
     : float3(-z.x * z.z, yz, 1.0f - z.z * z.z));
    
    float3 x = cross(y, z);
    return float3x3(x, y, z);
  }
  
  static float3 randomDirection(thread uint& seed, float3x3 basis) {
    // Generate a random number and increment the seed.
    float r1 = Sampling::radinv2(seed);
    float r2 = Sampling::radinv3(seed);
    seed += 1;
    
    // Transform the uniform distribution into the cosine distribution.
    float sq = sqrt(1.0 - r2);
    float3 direction(cos(2 * M_PI_F * r1) * sq,
                     sin(2 * M_PI_F * r1) * sq, sqrt(r2));
    
    // Apply the basis as a linear transformation.
    return basis * direction;
  }
  
  // TODO: Wrap the basis inside a context struct.
  static float queryOcclusion
   (
    float3 intersectionPoint, Atom atom, ushort2 pixelCoords, uint frameSeed,
    accel accel)
  {
    float3 position = intersectionPoint;
    float3 normal = normalize(intersectionPoint - atom.origin);
    float occlusion = 0.0;
    
    // Move origin slightly away from the surface to avoid self-occlusion.
    float3 origin = position + normal * float(0.001);
    float3x3 basis = makeBasis(normal);
    uint seed = Sampling::tea(as_type<uint>(pixelCoords), frameSeed);
    
    for (int i = 0; i < rtao_samples; ++i) {
      float3 direction = randomDirection(seed, basis);
      ray ray = secondaryRay(origin, direction);
      auto intersection = RayTracing::traverse(ray, accel);
      
      occlusion += intersection.accept ? 1.0 : 0.0;
    }
    
    occlusion = 1 - (occlusion / float(rtao_samples));
    occlusion = pow(clamp(occlusion, float(0), float(1)), rtao_power);
    return occlusion;
  }
};
