//
//  Constants.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 5/21/23.
//

#ifndef Constants_h
#define Constants_h

#include <metal_stdlib>
#include "AtomStatistics.metal"
using namespace metal;

// MARK: - Constants

// The MetalFX upscaler is currently configured with a static resolution.
constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];

// Whether to treat the specular term the same as the diffuse term when
// factoring in ambient occlusion. This suppresses the specular part in occluded
// areas. It is technically incorrect, but is sometimes preferable. The default
// setting is to not suppress the specular term.
constant bool SUPPRESS_SPECULAR [[function_constant(2)]];

// MARK: - Definitions

typedef raytracing::primitive_acceleration_structure accel;

struct Arguments {
  // This frame's position and orientation.
  float3 position;
  float3x3 cameraToWorldRotation;
  
  // How many pixels are covered in either direction @ FOV=90?
  float fov90Span;
  float fov90SpanReciprocal;
  
  // The jitter to apply to the pixel.
  float2 jitter;
  
  // Seed for generating random numbers.
  uint frameSeed;
  
  // Constants for Blinn-Phong shading.
  half lightPower;
  
  // Constants for ray-traced ambient occlusion.
  ushort sampleCount;
  float maxRayHitTime;
  float exponentialFalloffDecayConstant;
  float minimumAmbientIllumination;
  float diffuseReflectanceScale;
};

#endif
