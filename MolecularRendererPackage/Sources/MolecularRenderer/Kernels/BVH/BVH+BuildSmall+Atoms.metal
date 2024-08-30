//
//  BVH+BuildSmall+Atoms.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
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

// Test whether an atom overlaps a 1x1x1 cube.
inline bool cubeSphereIntersection(ushort3 cube_min, float4 atom)
{
  float3 c1 = float3(cube_min);
  float3 c2 = c1 + 1;
  float3 delta_c1 = atom.xyz - c1;
  float3 delta_c2 = atom.xyz - c2;
  
  float dist_squared = atom.w * atom.w;
#pragma clang loop unroll(full)
  for (int dim = 0; dim < 3; ++dim) {
    if (atom[dim] < c1[dim]) {
      dist_squared -= delta_c1[dim] * delta_c1[dim];
    } else if (atom[dim] > c2[dim]) {
      dist_squared -= delta_c2[dim] * delta_c2[dim];
    }
  }
  
  return dist_squared > 0;
}

kernel void buildSmallPart1_1
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device float4 *convertedAtoms [[buffer(1)]],
 device atomic_uint *smallCounterMetadata [[buffer(2)]],
 uint tid [[thread_position_in_grid]])
{
  // Transform the atom.
  float4 newAtom = convertedAtoms[tid];
  newAtom.xyz = 4 * (newAtom.xyz - bvhArgs->worldMinimum);
  newAtom.w = 4 * newAtom.w;
  
  // Generate the bounding box.
  ushort3 grid_dims = bvhArgs->smallVoxelCount;
  auto box_min = quantize(newAtom.xyz - newAtom.w, grid_dims);
  auto box_max = quantize(newAtom.xyz + newAtom.w, grid_dims);
  
  // Iterate over the footprint on the 3D grid.
  for (ushort z = box_min[2]; z <= box_max[2]; ++z) {
    for (ushort y = box_min[1]; y <= box_max[1]; ++y) {
      for (ushort x = box_min[0]; x <= box_max[0]; ++x) {
        ushort3 cube_min { x, y, z };
        
        // Narrow down the cells with a cube-sphere intersection test.
        bool mark = cubeSphereIntersection(cube_min, newAtom);
        if (mark) {
          uint address = VoxelAddress::generate(grid_dims, cube_min);
          address = address * 4;
          
          // Increment the counter.
          atomic_fetch_add_explicit(smallCounterMetadata + address,
                                    1, memory_order_relaxed);
        }
      }
    }
  }
}

kernel void buildSmallPart2_2
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device float4 *convertedAtoms [[buffer(1)]],
 device atomic_uint *smallCounterMetadata [[buffer(2)]],
 device uint *smallAtomReferences [[buffer(3)]],
 uint tid [[thread_position_in_grid]])
{
  // Transform the atom.
  float4 newAtom = convertedAtoms[tid];
  newAtom.xyz = 4 * (newAtom.xyz - bvhArgs->worldMinimum);
  newAtom.w = 4 * newAtom.w;
  
  // Generate the bounding box.
  ushort3 grid_dims = bvhArgs->smallVoxelCount;
  auto box_min = quantize(newAtom.xyz - newAtom.w, grid_dims);
  auto box_max = quantize(newAtom.xyz + newAtom.w, grid_dims);
  
  // Iterate over the footprint on the 3D grid.
  for (ushort z = box_min[2]; z <= box_max[2]; ++z) {
    for (ushort y = box_min[1]; y <= box_max[1]; ++y) {
      for (ushort x = box_min[0]; x <= box_max[0]; ++x) {
        ushort3 cube_min { x, y, z };
        
        // Narrow down the cells with a cube-sphere intersection test.
        bool mark = cubeSphereIntersection(cube_min, newAtom);
        if (mark) {
          uint address = VoxelAddress::generate(grid_dims, cube_min);
          address = address * 4;
          
          // Increment the counter.
          uint offset =
          atomic_fetch_add_explicit(smallCounterMetadata + address,
                                    1, memory_order_relaxed);
          
          // Write the reference to the list.
          if (offset < dense_grid_reference_capacity) {
            smallAtomReferences[offset] = uint(tid);
          }
        }
      }
    }
  }
}
