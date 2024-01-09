//
//  Constants.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 5/21/23.
//

#ifndef Constants_h
#define Constants_h

#include <metal_stdlib>
using namespace metal;

// MARK: - Constants

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"

// The MetalFX upscaler is currently configured with a static resolution.
constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];
constant bool OFFLINE [[function_constant(2)]];

// Whether to use 64-bit cell descriptors. For now, this must be changed
// manually when enabling extreme system sizes. Eventually, a more elegant
// implementation will select a function variant at app launch.
#define SCENE_SIZE_EXTREME 0

// Safeguard against infinite loops. Disable this for profiling.
#define FAULT_COUNTERS_ENABLE 1

// Voxel width in nm.
constant float voxel_width_numer [[function_constant(10)]];
constant float voxel_width_denom [[function_constant(11)]];

#if SCENE_SIZE_EXTREME
typedef uint2 VOXEL_DATA;

constant uint dense_grid_reference_capacity = __UINT32_MAX__;
constant uint voxel_reference_capacity = __UINT32_MAX__;
#else
// Max 16 million atoms/dense grid, including duplicated references.
// Max ~5 million atoms/dense grid, excluding duplicated references.
// Max 256 references/voxel.
constant uint dense_grid_reference_capacity = 16 * 1024 * 1024;
constant uint voxel_reference_capacity = 256;

// Count is stored in opposite-endian order to the offset.
constant uint voxel_offset_mask = dense_grid_reference_capacity - 1;
constant uint voxel_count_mask = 0xFFFFFFFF - voxel_offset_mask;

typedef uint VOXEL_DATA;
#endif

// MARK: - Definitions

struct __attribute__((aligned(16)))
Arguments {
  // Transforms a pixel location on the screen into a ray direction vector.
  float fovMultiplier;
  
  // This frame's position and orientation.
  packed_float3 position;
  float3x3 rotation;
  
  // The jitter to apply to the pixel.
  float2 jitter;
  
  // Seed for generating random numbers.
  uint frameSeed;

  // Constants for Blinn-Phong shading.
  ushort numLights;
  
  // Constants for ray-traced ambient occlusion.
  half minSamples;
  half maxSamples;
  half qualityCoefficient; // 30
  
  // Constants for the ambient occlusion cutoff.
  float maxRayHitTime;
  float exponentialFalloffDecayConstant;
  float minimumAmbientIllumination;
  float diffuseReflectanceScale;
  
  // Uniform grid arguments.
  ushort3 dense_dims;
};

#pragma clang diagnostic pop

#endif
