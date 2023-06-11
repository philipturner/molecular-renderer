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

class RayGeneration {
public:
  struct Basis {
    // Basis for the coordinate system around the normal vector.
    float3x3 axes;

    // Uniformly distributed random numbers for determining angles.
    float random1;
    float random2;
  };
  
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
  
  static float3x3 makeBasis(const float3 normal) {
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
  
  static ray primaryRay(ushort2 pixelCoords, constant Arguments* args) {
    float3 rayDirection(float2(pixelCoords) + 0.5, -1);
    rayDirection.xy += args->jitter;
    rayDirection.xy -= float2(SCREEN_WIDTH, SCREEN_HEIGHT) / 2;
    rayDirection.y = -rayDirection.y;
    rayDirection.xy *= args->fovMultiplier;
    rayDirection = normalize(rayDirection);
    rayDirection = args->cameraToWorldRotation * rayDirection;
    
    float3 worldOrigin = args->position;
    return { worldOrigin, rayDirection };
  }
  
  static ray secondaryRay(float3 origin, Basis basis) {
    // Transform the uniform distribution into the cosine distribution. This
    // creates a direction vector that's already normalized.
    float phi = 2 * M_PI_F * basis.random1;
    float cosThetaSquared = basis.random2;
    float sinTheta = sqrt(1.0 - cosThetaSquared);
    float3 direction(cos(phi) * sinTheta,
                     sin(phi) * sinTheta, sqrt(cosThetaSquared));
    
    // Apply the basis as a linear transformation.
    direction = basis.axes * direction;
    
    ray ray;
    ray.origin = origin;
    ray.direction = direction;
    return ray;
  }
};
