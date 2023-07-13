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
constant float SCREEN_MAGNITUDE = sqrt(float(SCREEN_WIDTH * SCREEN_HEIGHT));
constant float SCREEN_RELATIVE_MAGNITUDE = 640 * SCREEN_MAGNITUDE;

// Safeguard against infinite loops. Disable this for profiling.
#define FAULT_COUNTERS_ENABLE 0

// Voxel width in nm.
constant float voxel_width_numer = 4;
constant float voxel_width_denom = 9;

// Max 8 million atoms/dense grid, including duplicated references.
// Max 1 million atoms/dense grid, excluding duplicated references.
// Max 512 references/voxel.
constant uint dense_grid_reference_capacity = 8 * 1024 * 1024;
constant uint voxel_reference_capacity = 512;

// Count is stored in opposite-endian order to the offset.
constant uint voxel_offset_mask = dense_grid_reference_capacity - 1;
constant uint voxel_count_mask = 0xFFFFFFFF - voxel_offset_mask;

// When we have sparse grids, the references can be `ushort`.
typedef uint REFERENCE;

// MARK: - Definitions

struct __attribute__((aligned(16)))
Arguments {
  // Transforms a pixel location on the screen into a ray direction vector.
  float fovMultiplier;
  
  // This frame's position and orientation.
  packed_float3 position;
  float3x3 cameraToWorldRotation;
  
  // The jitter to apply to the pixel.
  float2 jitter;
  
  // Seed for generating random numbers.
  uint frameSeed;

  // Constants for Blinn-Phong shading.
  ushort numLights;
  
  // Constants for ray-traced ambient occlusion.
  half sampleCount;
  float maxRayHitTime;
  float exponentialFalloffDecayConstant;
  float minimumAmbientIllumination;
  float diffuseReflectanceScale;
  
  // Uniform grid arguments.
  ushort grid_width;
};

#pragma clang diagnostic pop

#endif
