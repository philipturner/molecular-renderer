//
//  Constants.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 5/21/23.
//

#ifndef CONSTANTS_H
#define CONSTANTS_H

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

// MARK: - Definitions

struct CameraArguments {
  float4 positionAndFOVMultiplier;
  float3 rotationColumn1;
  float3 rotationColumn2;
  float3 rotationColumn3;
  float2 jitter;
};

struct BVHArguments {
  float3 worldMinimum;
  float3 worldMaximum;
  ushort3 largeVoxelCount;
  ushort3 smallVoxelCount;
};

struct RenderArguments {
  uint frameSeed;
  float qualityCoefficient;
  bool useAtomMotionVectors;
};

#endif // CONSTANTS_H
