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
  
  uint atomicNumber = uint(atom[3]);
  half radius = styles[atomicNumber].w;
  
  ushort2 tail = as_type<ushort2>(atom[3]);
  tail[0] = as_type<ushort>(half(radius * radius));
  tail[1] = ushort(atomicNumber);
  atom[3] = as_type<float>(tail);
  
  atoms[tid] = atom;
}
