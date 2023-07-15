//
//  Memory.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
//

#include <metal_stdlib>
using namespace metal;

constant uint pattern4 [[function_constant(1000)]];

kernel void memset_pattern4
(
 device uint *b [[buffer(0)]],
 uint tid [[thread_position_in_grid]])
{
  b[tid] = pattern4;
}
