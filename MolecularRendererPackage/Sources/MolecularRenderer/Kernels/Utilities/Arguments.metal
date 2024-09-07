//
//  Arguments.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 5/21/23.
//

#ifndef ARGUMENTS_H
#define ARGUMENTS_H

#include <metal_stdlib>
using namespace metal;

struct CameraArguments {
  float3 position;
  float3 rotationColumn1;
  float3 rotationColumn2;
  float3 rotationColumn3;
  float fovMultiplier;
};

struct RenderArguments {
  ushort screenWidth;
  uint frameSeed;
  float2 jitterOffsets;
  float qualityCoefficient;
};

#endif // ARGUMENTS_H
