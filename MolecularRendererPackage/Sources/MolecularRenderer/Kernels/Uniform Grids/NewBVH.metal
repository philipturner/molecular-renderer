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
 device float4 *atoms [[buffer(0)]],
 device half4 *styles [[buffer(2)]],
 device float4 *newAtoms [[buffer(3)]],
 
 uint tid [[thread_position_in_grid]])
{
  // Fetch the atom from memory.
  float4 atom = atoms[tid];
  
  // Overwrite the atom's tail in memory.
  {
    ushort atomicNumber = ushort(atom[3]);
    half radius = styles[atomicNumber].w;
    
    ushort2 tail;
    tail[0] = as_type<ushort>(half(radius * radius));
    tail[1] = ushort(atomicNumber);
    atoms[tid].w = as_type<float>(tail);
  }
  
  // Write the new format.
  {
    ushort atomicNumber = ushort(atom[3]);
    float radius = styles[atomicNumber].w;
    
    uint packed = as_type<uint>(radius);
    packed = packed & 0xFFFFFF00;
    packed = packed | atomicNumber;
    
    float4 convertedAtom = atom;
    convertedAtom.w = as_type<float>(packed);
    newAtoms[tid] = convertedAtom;
  }
}
