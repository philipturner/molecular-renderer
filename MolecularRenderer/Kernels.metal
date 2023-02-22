//
//  Kernels.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
using namespace metal;

constant uint SCREEN_WIDTH = 1024;
constant uint SCREEN_HEIGHT = 1024;

// https://en.wikipedia.org/wiki/HSL_and_HSV#Color_conversion_formulae
half3 convert_hsl_to_rgb(half hue, half saturation, half lightness) {
  half3 k = half3(0, 8, 4) + hue / half(30);
  k -= select(half3(0), half3(12), k >= 12);
  half a = saturation * min(lightness, 1 - lightness);
  return lightness - a * max(-1, min3(k - 3, 9 - k, 1));
}

// Dispatch threadgroups across 16x16 chunks, not rounded to image size.
// This shader will rearrange simds across 8x2 to 8x8 chunks.
kernel void renderScene(texture2d<half, access::write> outputTexture [[texture(0)]],
                        
                        // Time in seconds.
                        constant float &time [[buffer(0)]],
                        ushort2 tid [[thread_position_in_grid]],
                        ushort2 tgid [[threadgroup_position_in_grid]],
                        ushort2 local_id [[thread_position_in_threadgroup]])
{
  ushort2 new_local_id = local_id;
  new_local_id.y *= 2;
  if (new_local_id.x % 16 >= 8) {
    new_local_id.y += 1;
    new_local_id.x -= 8;
  }
  if (new_local_id.y >= 16) {
    new_local_id.y -= 16;
    new_local_id.x += 8;
  }
  
  ushort2 pixelCoords = tgid * 16 + new_local_id;
  if (SCREEN_WIDTH % 16 != 0) {
    if (pixelCoords.x >= SCREEN_WIDTH) {
      return;
    }
  }
  if (SCREEN_HEIGHT % 16 != 0) {
    if (pixelCoords.y >= SCREEN_HEIGHT) {
      return;
    }
  }
  
  float2 normalizedCoords = float2(pixelCoords) + 0.5;
  normalizedCoords /= float2(SCREEN_WIDTH, SCREEN_HEIGHT);
  if (pixelCoords.y >= SCREEN_HEIGHT - 128) {
    normalizedCoords.x += fract(time);
    normalizedCoords.x -= select(float(0), float(1), normalizedCoords.x >= 1);
  }
  
  // Top of screen is white, bottom is full color.
  // Left to right, it interpolates all the way from red to blue.
  half hue = normalizedCoords.x * 360;
  half saturation = 1.0;
  half lightness = 1.0 - normalizedCoords.y;
  half3 color = convert_hsl_to_rgb(hue, saturation, lightness);
  outputTexture.write(half4(color, 1), pixelCoords);
}
