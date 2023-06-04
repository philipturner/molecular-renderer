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

// This does not need to become dynamic. Changing the resolution will mess up
// MetalFX upscaling.
constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];
constant bool USE_METALFX [[function_constant(2)]];

// Constants for Blinn-Phong shading.
constant float LIGHT_POWER = 50.0;

// Constants for ray-traced ambient occlusion.
constant bool USE_RTAO = true;
constant ushort RTAO_SAMPLES = 3; // 64

// Whether to suppress the specular term in occluded areas.
constant bool SUPPRESS_SPECULAR = true;

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
  
  // Constants for ray-traced ambient occlusion.
  float maxRayHitTime;
  float exponentialFalloffDecayConstant;
  float minimumAmbientIllumination;
  float diffuseReflectanceScale;
};

#endif
