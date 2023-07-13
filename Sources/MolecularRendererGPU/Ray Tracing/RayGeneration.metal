//
//  RayGeneration.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 4/22/23.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "RayTracing.metal"
#include "Sampling.metal"
using namespace metal;

// Partially sourced from:
// https://github.com/nvpro-samples/gl_vk_raytrace_interop/blob/master/shaders/raygen.rgen
// https://github.com/microsoft/DirectX-Graphics-Samples/tree/master/Samples/Desktop/D3D12Raytracing/src/D3D12RaytracingRealTimeDenoisedAmbientOcclusion/RTAO

class RayGeneration {
public:
  struct Basis {
    // Basis for the coordinate system around the normal vector.
    // TODO: Store axes in half3x3
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
  
  static Ray primaryRay(ushort2 pixelCoords, constant Arguments* args) {
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
  
  static Ray secondaryRay(float3 origin, Basis basis) {
    // Transform the uniform distribution into the cosine distribution. This
    // creates a direction vector that's already normalized.
    float phi = 2 * M_PI_F * basis.random1;
    float cosThetaSquared = basis.random2;
    float sinTheta = sqrt(1.0 - cosThetaSquared);
    float3 direction(cos(phi) * sinTheta,
                     sin(phi) * sinTheta, sqrt(cosThetaSquared));
    
    // Apply the basis as a linear transformation.
    direction = basis.axes * direction;
    return { origin, direction };
  }
};

class GenerationContext {
  constant Arguments* args;
  
  // TODO: Store axes in half3x3
  float3 origin;
  float3x3 axes;
  uint seed;
  
public:
  GenerationContext(constant Arguments* args,
                    ushort2 pixelCoords, float3 hitPoint, float3 normal) {
    this->args = args;
    
    // Move origin slightly away from the surface to avoid self-occlusion.
    // Switching to a uniform grid acceleration structure should make it
    // possible to ignore this parameter.
    this->origin = hitPoint + normal * float(0.001);
    
    // Align the atoms' coordinate systems with each other, to minimize
    // divergence. Here is a primitive method that achieves that by aligning
    // the X and Y dimensions to a common coordinate space.
    float3 modNormal = transpose(args->cameraToWorldRotation) * normal;
    this->axes = RayGeneration::makeBasis(modNormal);
    this->axes = args->cameraToWorldRotation * axes;
    
    uint pixelSeed = as_type<uint>(pixelCoords);
    this->seed = Sampling::tea(pixelSeed, args->frameSeed);
  }
  
  Ray generate(ushort i, ushort samples) {
    // Generate a random number and increment the seed.
    float random1 = Sampling::radinv3(seed);
    float random2 = Sampling::radinv2(seed);
    seed += 1;
    
    float sampleCountRecip = fast::divide(1, float(samples));
    float minimum = float(i) * sampleCountRecip;
    float maximum = minimum + sampleCountRecip;
    maximum = (i == samples - 1) ? 1 : maximum;
    random1 = mix(minimum, maximum, random1);
     
    // Create a random ray from the cosine distribution.
    RayGeneration::Basis basis { axes, random1, random2 };
    return RayGeneration::secondaryRay(origin, basis);
  }
};
