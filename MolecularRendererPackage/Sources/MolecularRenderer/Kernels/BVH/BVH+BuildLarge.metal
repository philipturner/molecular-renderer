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

kernel void buildLargePart1
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device atomic_uint *largeCellMetadata [[buffer(1)]],
 device float4 *convertedAtoms [[buffer(2)]],
 
 uint tid [[thread_position_in_grid]])
{
  // Transform the atom.
  float4 newAtom = convertedAtoms[tid];
  newAtom.xyz = 4 * (newAtom.xyz - bvhArgs->worldMinimum);
  newAtom.w = 4 * newAtom.w;
  
  // Generate the bounding box.
  short3 small_voxel_min = short3(floor(newAtom.xyz - newAtom.w));
  short3 small_voxel_max = short3(ceil(newAtom.xyz + newAtom.w));
  small_voxel_min = max(small_voxel_min, 0);
  small_voxel_max = max(small_voxel_max, 0);
  small_voxel_min = min(small_voxel_min, short3(bvhArgs->smallVoxelCount));
  small_voxel_max = min(small_voxel_max, short3(bvhArgs->smallVoxelCount));
  auto large_voxel_min = small_voxel_min / 8;
  auto large_voxel_max = small_voxel_max / 8;
  
  // Pre-compute the footprint.
  short3 dividingLine = large_voxel_max * 8;
  dividingLine = min(dividingLine, small_voxel_max);
  dividingLine = max(dividingLine, small_voxel_min);

#define FORCE_UNROLLED 0
  
  short3 footprintLow = dividingLine - small_voxel_min;
  short3 footprintHigh = small_voxel_max - dividingLine;
  ushort3 loopStart = select(ushort3(1),
                             ushort3(0),
                             footprintLow > 0);
  ushort3 loopEnd = select(ushort3(1),
                           ushort3(2),
                           footprintHigh > 0);
  
//  ushort3 loopStart = 0;
//  ushort3 loopEnd = 2;
  
  // Iterate over the footprint on the 3D grid.
  for (ushort z = loopStart[2]; z < loopEnd[2]; ++z) {
    for (ushort y = loopStart[1]; y < loopEnd[1]; ++y) {
      for (ushort x = loopStart[0]; x < loopEnd[0]; ++x) {
        ushort3 xyz(x, y, z);
        short3 footprint = select(footprintLow, footprintHigh, bool3(xyz));
        
#if !FORCE_UNROLLED
        
#else
        if (all(footprint > 0))
#endif
        {
          ushort3 cube_min = ushort3(large_voxel_min) + xyz;
          ushort3 grid_dims = bvhArgs->largeVoxelCount;
          uint address = VoxelAddress::generate(grid_dims, cube_min);
          address = (address * 8) + (tid % 8);
          
          uint smallReferenceCount =
          footprint[0] * footprint[1] * footprint[2];
          uint word = 1;//(smallReferenceCount << 14) + 1;
          atomic_fetch_add_explicit(largeCellMetadata + address,
                                    word, memory_order_relaxed);
        }
      }
    }
  }
}
