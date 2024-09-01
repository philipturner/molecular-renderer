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

constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];

struct CameraArguments {
  float3 position;
  float3 rotationColumn1;
  float3 rotationColumn2;
  float3 rotationColumn3;
  float fovMultiplier;
};

struct BVHArguments {
  float3 worldMinimum;
  float3 worldMaximum;
  ushort3 largeVoxelCount;
  ushort3 smallVoxelCount;
};

struct RenderArguments {
  uint frameSeed;
  float2 jitterOffsets;
  float qualityCoefficient;
};

#endif // CONSTANTS_H
