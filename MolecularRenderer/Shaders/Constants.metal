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

// This does not need to become dynamic. Changing the resolution will mess up
// MetalFX upscaling.
constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];
constant bool USE_METALFX [[function_constant(2)]];

typedef raytracing::primitive_acceleration_structure accel;

#define USE_RTAO 1

struct Arguments {
  // This frame's position and orientation.
  float3 position;
  float3x3 rotation;
  
  // How many pixels are covered in either direction @ FOV=90?
  float fov90Span;
  float fov90SpanReciprocal;
  
  // The jitter to apply to the pixel.
  float2 jitter;
  
  // Seed for generating random numbers.
  uint frameSeed;
};

#endif
