//
//  BVH+BuildLarge.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/26/24.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "../Utilities/VoxelAddress.metal"
using namespace metal;

// Quantize a position relative to the world origin.
inline ushort3 quantize(float3 position, ushort3 world_dims) {
  short3 output = short3(position);
  output = clamp(output, 0, short3(world_dims));
  return ushort3(output);
}

// Tasks:
// - Replicate 'buildSmallPart1'. [DONE]
// - Switch to generating the large voxel coordinate from the small voxel
//   coordinate.
// - Count the atom's footprint in each of 8 voxels.
//   - Match the reference count from the "bounding box" algorithm.
// - Accumulate both metrics at the same time.
kernel void buildLargePart1
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device atomic_uint *largeCellMetadata [[buffer(1)]],
 device float4 *convertedAtoms [[buffer(2)]],
 
 uint tid [[thread_position_in_grid]])
{
  // Original code
#if 0
  // Transform the atom.
  float4 newAtom = convertedAtoms[tid];
  newAtom.xyz = (newAtom.xyz - bvhArgs->worldMinimum) / 2;
  newAtom.w = newAtom.w / 2;
  
  // Generate the bounding box.
  ushort3 grid_dims = bvhArgs->largeVoxelCount;
  auto box_min = quantize(newAtom.xyz - newAtom.w, grid_dims);
  auto box_max = quantize(newAtom.xyz + newAtom.w, grid_dims);
  
  // Iterate over the footprint on the 3D grid.
  for (ushort z = box_min[2]; z <= box_max[2]; ++z) {
    for (ushort y = box_min[1]; y <= box_max[1]; ++y) {
      for (ushort x = box_min[0]; x <= box_max[0]; ++x) {
        ushort3 cube_min { x, y, z };
        
        // Increment the voxel's counter.
        uint address = VoxelAddress::generate(grid_dims, cube_min);
        address = (address * 8) + (tid % 8);
        atomic_fetch_add_explicit(largeCellMetadata + address,
                                  1, memory_order_relaxed);
      }
    }
  }
  
  // New Code
#else
  // Transform the atom.
  float4 newAtom = convertedAtoms[tid];
  newAtom.xyz = 4 * (newAtom.xyz - bvhArgs->worldMinimum);
  newAtom.w = 4 * newAtom.w;
  
  // Generate the bounding box.
  ushort3 small_grid_dims = bvhArgs->smallVoxelCount;
  auto small_voxel_min = quantize(newAtom.xyz - newAtom.w, small_grid_dims);
  auto small_voxel_max = quantize(newAtom.xyz + newAtom.w, small_grid_dims);
  auto large_voxel_min = small_voxel_min / 8;
  auto large_voxel_max = small_voxel_max / 8;
  
  // Iterate over the footprint on the 3D grid.
  for (ushort z = large_voxel_min[2]; z <= large_voxel_max[2]; ++z) {
    for (ushort y = large_voxel_min[1]; y <= large_voxel_max[1]; ++y) {
      for (ushort x = large_voxel_min[0]; x <= large_voxel_max[0]; ++x) {
        ushort3 cube_min { x, y, z };
        
        // Increment the voxel's counter.
        auto large_grid_dims = bvhArgs->largeVoxelCount;
        uint address = VoxelAddress::generate(large_grid_dims, cube_min);
        address = (address * 8) + (tid % 8);
        atomic_fetch_add_explicit(largeCellMetadata + address,
                                  1, memory_order_relaxed);
      }
    }
  }
#endif
}
