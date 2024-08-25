//
//  NewBVH.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/18/24.
//

#include <metal_stdlib>
#include "../Utilities/Atomic.metal"
using namespace metal;

// Converts the float4 atoms to two different formats (for now).
kernel void preprocess
(
 device float4 *originalAtoms [[buffer(0)]],
 device float *atomRadii [[buffer(1)]],
 device float4 *convertedAtoms [[buffer(2)]],
 
 uint tid [[thread_position_in_grid]])
{
  // Fetch the atom from memory.
  float4 atom = originalAtoms[tid];
  
  // Write the new format.
  {
    ushort atomicNumber = ushort(atom[3]);
    float radius = atomRadii[atomicNumber];
    
    uint packed = as_type<uint>(radius);
    packed = packed & 0xFFFFFF00;
    packed = packed | atomicNumber;
    
    float4 convertedAtom = atom;
    convertedAtom.w = as_type<float>(packed);
    convertedAtoms[tid] = convertedAtom;
  }
}
