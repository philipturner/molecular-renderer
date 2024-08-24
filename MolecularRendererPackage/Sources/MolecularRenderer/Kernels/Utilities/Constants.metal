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

constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];

// Max 64 million atoms/dense grid, including duplicated references.
// Max ~5 million atoms/dense grid, excluding duplicated references.
// Max 64 references/voxel.
constant uint dense_grid_reference_capacity = 64 * 1024 * 1024;

// Count is stored in opposite-endian order to the offset.
constant uint voxel_offset_mask = dense_grid_reference_capacity - 1;
constant uint voxel_count_mask = 0xFFFFFFFF - voxel_offset_mask;

constant float MAX_RAY_HIT_TIME = 1.0;

// MARK: - Definitions

struct RenderArguments {
  // The jitter to apply to the pixel.
  float2 jitter;
  
  // Seed for generating random numbers.
  uint frameSeed;
  
  // Constants for ray-traced ambient occlusion.
  float qualityCoefficient;
  
  // Uniform grid arguments.
  short3 world_origin;
  short3 world_dims;
};

struct CameraArguments {
  float4 positionAndFOVMultiplier;
  float3 rotationColumn1;
  float3 rotationColumn2;
  float3 rotationColumn3;
};

#pragma clang diagnostic pop

#endif
