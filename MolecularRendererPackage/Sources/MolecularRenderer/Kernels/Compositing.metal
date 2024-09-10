//
//  Compositing.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 9/9/24.
//

#include <metal_stdlib>
using namespace metal;

// Amplify the upscale factor from 3x to 4x, and composite the
// user-specified mask.
kernel void compositeFinalImage
(
 texture2d<half, access::sample> upscaledTexture [[texture(0)]],
 texture2d<half, access::write> drawableTexture [[texture(1)]],
 ushort2 tid [[thread_position_in_grid]])
{
  constexpr float upscaleFactor = 4.0 / 3;
  float2 samplePosition = float2(tid);
  samplePosition += 0.5;
  samplePosition /= upscaleFactor;
  
  // To port this to Windows, we'll need to reverse engineer the
  // hardware-accelerated bicubic sampling on Apple GPUs.
  constexpr sampler upscaledTextureSampler(coord::pixel,
                                           address::clamp_to_zero,
                                           filter::bicubic);
  half4 color = upscaledTexture
    .sample(upscaledTextureSampler, samplePosition);
  drawableTexture.write(color, tid);
}
