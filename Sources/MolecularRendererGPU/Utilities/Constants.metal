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

// The MetalFX upscaler is currently configured with a static resolution.
constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];

// Safeguard against infinite loops. Disable this for profiling.
#define FAULT_COUNTERS_ENABLE 0

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
  half lightPower;
  bool cameraIsLight;
  ushort nonCameraLights;
  
  // Constants for ray-traced ambient occlusion.
  ushort sampleCount;
  float maxRayHitTime;
  float exponentialFalloffDecayConstant;
  float minimumAmbientIllumination;
  float diffuseReflectanceScale;
  
  // Uniform grid arguments.
  ushort grid_width;
};

#endif
