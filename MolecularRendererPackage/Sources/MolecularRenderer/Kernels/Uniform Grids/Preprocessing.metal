//
//  Preprocessing.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/18/24.
//

#include <metal_stdlib>
#include "../Utilities/Atomic.metal"
using namespace metal;

kernel void preprocessAtoms
(
 device float4 *atoms [[buffer(1)]],
 device half4 *styles [[buffer(2)]],
 device uint *voxel_data [[buffer(4)]],
 
 uint tid [[thread_position_in_grid]])
{
  // Fetch the atom from memory.
  float4 atom = atoms[tid];
  ushort atomicNumber = ushort(atom[3]);
  half radius = styles[atomicNumber].w;
  
  // Overwrite the atom's tail in memory.
  {
    ushort2 tail;
    tail[0] = as_type<ushort>(half(radius * radius));
    tail[1] = ushort(atomicNumber);
    atoms[tid].w = as_type<float>(tail);
  }
  
  // Locate the closest voxel.
  float3 position = atom.xyz;
  float3 shiftedPosition = position + 64;
  short3 voxelCoords = short3(floor(shiftedPosition / 2));
  uint voxelAddress =
  voxelCoords.z * (64 * 64) + voxelCoords.y * 64 + voxelCoords.x;
  
  // Atomically increment the voxel's counter.
  atomic_fetch_add(voxel_data + voxelAddress, 1);
}
