//
//  Compositing.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 9/9/24.
//

#include <metal_stdlib>
using namespace metal;

// Amplify the upscale factor from 3x to 6x, and composite the
// user-specified mask.
kernel void compositeFinalImage
(
 texture2d<half, access::read> upscaledTexture [[texture(0)]],
 texture2d<half, access::write> drawableTexture [[texture(1)]],
 ushort2 tid [[thread_position_in_grid]])
{
  half4 color = upscaledTexture.read(tid);
  drawableTexture.write(color, tid);
}
