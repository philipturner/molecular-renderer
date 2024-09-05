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

#endif // CONSTANTS_H
