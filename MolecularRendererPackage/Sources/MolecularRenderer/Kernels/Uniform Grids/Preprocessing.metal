//
//  Preprocessing.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/18/24.
//

#include <metal_stdlib>
using namespace metal;

kernel void preprocessAtoms
(
 const device half4 *styles [[buffer(0)]],
 device float4 *atoms [[buffer(1)]],
 
 uint tid [[thread_position_in_grid]])
{
  float4 atom = atoms[tid];
  atoms[tid] = atom;
}
