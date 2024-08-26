//
//  ResetMemory.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/26/24.
//

#include <metal_stdlib>
using namespace metal;

// Fills the memory allocation with the specified pattern.
kernel void resetMemory1D
(
 device uint *b [[buffer(0)]],
 constant uint &pattern [[buffer(1)]],
 
 uint tid [[thread_position_in_grid]])
{
  b[tid] = pattern;
}
