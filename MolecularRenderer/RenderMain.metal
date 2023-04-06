//
//  RenderMain.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
using namespace metal;

constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];
constant float FOV_90_SPAN_RECIPROCAL [[function_constant(2)]];

// Dispatch threadgroups across 16x16 chunks, not rounded to image size.
// This shader will rearrange simds across 8x2 to 8x8 chunks (depending on the
// GPU architecture).
kernel void renderMain
 (
  texture2d<half, access::write> outputTexture [[texture(0)]],
  
  // Time in seconds.
  constant float &time1 [[buffer(0)]],
  constant float &time2 [[buffer(1)]],
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
  
  float3 rayDirection(float2(pixelCoords) + 0.5, -1);
  rayDirection.xy -= float2(SCREEN_WIDTH, SCREEN_HEIGHT) / 2;
  rayDirection.y = -rayDirection.y;
  rayDirection.xy *= FOV_90_SPAN_RECIPROCAL;
  
  half3 color = { 0, 0, 0 };
  color.r = saturate(abs(rayDirection.x) / 0.9);
  color.b = saturate(abs(rayDirection.y) / 0.9);
  
  outputTexture.write(half4(color, 1), pixelCoords);
}
