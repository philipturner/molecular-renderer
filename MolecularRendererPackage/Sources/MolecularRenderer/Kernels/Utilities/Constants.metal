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

struct CameraArguments {
  float4 positionAndFOVMultiplier;
  float3 rotationColumn1;
  float3 rotationColumn2;
  float3 rotationColumn3;
};

struct BVHArguments {
  short3 worldOrigin;
  short3 worldDimensions;
};

struct RenderArguments {
  float2 jitter;
  uint frameSeed;
  float qualityCoefficient;
};

#endif
