//
//  OldBVH.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
//

#include <metal_stdlib>
#include "../Utilities/Atomic.metal"
#include "DDA.metal"
using namespace metal;

struct DenseGridArguments {
  short3 world_origin;
  short3 world_dims;
};

// MARK: - Cube-Sphere Intersection

METAL_FUNC bool cube_sphere_intersection(ushort3 cube_min,
                                         float3 origin,
                                         float radiusSquared)
{
  float3 c1 = float3(cube_min);
  float3 c2 = c1 + 1;
  float3 delta_c1 = origin - c1;
  float3 delta_c2 = origin - c2;
  
  float dist_squared = radiusSquared;
#pragma clang loop unroll(full)
  for (int dim = 0; dim < 3; ++dim) {
    if (origin[dim] < c1[dim]) {
      dist_squared -= delta_c1[dim] * delta_c1[dim];
    } else if (origin[dim] > c2[dim]) {
      dist_squared -= delta_c2[dim] * delta_c2[dim];
    }
  }
  
  return dist_squared > 0;
}

// MARK: - Pass 1

kernel void dense_grid_pass1
(
 constant DenseGridArguments &args [[buffer(0)]],
 device atomic_uint *dense_grid_data [[buffer(3)]],
 device float4 *newAtoms [[buffer(10)]],
 
 uint tid [[thread_position_in_grid]])
{
  float4 newAtom = newAtoms[tid];
  ushort3 grid_dims = ushort3(4 * args.world_dims);
  
  // Generate the box minimum.
  float3 MRBox_min = newAtom.xyz - newAtom.w;
  MRBox_min -= float3(args.world_origin);
  MRBox_min /= 0.25;
  ushort3 box_min;
  {
    short3 s_min = short3(MRBox_min);
    s_min = clamp(s_min, 0, short3(grid_dims));
    box_min = ushort3(s_min);
  }
  
  // Generate the box maximum.
  float3 MRBox_max = newAtom.xyz + newAtom.w;
  MRBox_max -= float3(args.world_origin);
  MRBox_max /= 0.25;
  ushort3 box_max;
  {
    short3 s_max = short3(MRBox_max);
    s_max = clamp(s_max, 0, short3(grid_dims));
    box_max = ushort3(s_max);
  }
  
  // Transform the origin and radius.
  float3 origin = newAtom.xyz;
  origin -= float3(args.world_origin);
  origin /= 0.25;
  float radiusSquared = (newAtom.w * newAtom.w) / (0.25 * 0.25);
  
  for (ushort z = box_min[2]; z <= box_max[2]; ++z) {
    for (ushort y = box_min[1]; y <= box_max[1]; ++y) {
      for (ushort x = box_min[0]; x <= box_max[0]; ++x) {
        ushort3 cube_min { x, y, z };
        
        // Narrow down the cells with a cube-sphere intersection test.
        bool mark = cube_sphere_intersection(cube_min, origin, radiusSquared);
        if (mark) {
          uint address = VoxelAddress::generate(grid_dims, cube_min);
          atomic_fetch_add(dense_grid_data + address, 1);
        }
      }
    }
  }
}

// MARK: - Pass 2

kernel void dense_grid_pass2
(
 constant DenseGridArguments &args [[buffer(0)]],
 device uint *dense_grid_data [[buffer(3)]],
 device uint *dense_grid_counters [[buffer(4)]],
 device atomic_uint *global_counter [[buffer(5)]],
 
 // 128 threads/threadgroup
 uint tid [[thread_position_in_grid]],
 ushort sidx [[simdgroup_index_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]])
{
  // Allocate extra cells if the total number isn't divisible by 128. The first
  // pass should zero them out.
  uint voxel_count = dense_grid_data[tid];
  uint prefix_sum_results = simd_prefix_exclusive_sum(voxel_count);
  
  threadgroup uint group_results[4];
  if (lane_id == 31) {
    group_results[sidx] = prefix_sum_results + voxel_count;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Prefix sum across simds.
  if (sidx == 0 && lane_id < 4) {
    uint voxel_count = group_results[lane_id];
    uint prefix_sum_results = quad_prefix_exclusive_sum(voxel_count);
    
    // Increment device atomic.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wuninitialized"
    uint group_offset;
    if (lane_id == 3) {
      uint total_voxel_count = prefix_sum_results + voxel_count;
      group_offset = atomic_fetch_add_explicit
      (
       global_counter, total_voxel_count, memory_order_relaxed);
    }
    prefix_sum_results += quad_broadcast(group_offset, 3);
#pragma clang diagnostic pop
    group_results[lane_id] = prefix_sum_results;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  prefix_sum_results += group_results[sidx];
  prefix_sum_results = min(prefix_sum_results, dense_grid_reference_capacity);
  
  uint next_offset = prefix_sum_results + voxel_count;
  next_offset = min(next_offset, dense_grid_reference_capacity);
  voxel_count = next_offset - prefix_sum_results;
  
  // Overwrite contents of the grid.
  uint count_part = reverse_bits(voxel_count) & voxel_count_mask;
  uint offset_part = prefix_sum_results & voxel_offset_mask;
  dense_grid_data[tid] = count_part | offset_part;
  dense_grid_counters[tid] = prefix_sum_results;
}

// MARK: - Pass 3

kernel void dense_grid_pass3
(
 constant DenseGridArguments &args [[buffer(0)]],
 device atomic_uint *dense_grid_counters [[buffer(4)]],
 device uint *references [[buffer(6)]],
 device float4 *newAtoms [[buffer(10)]],
 
 uint tid [[thread_position_in_grid]])
{
  float4 newAtom = newAtoms[tid];
  ushort3 grid_dims = ushort3(4 * args.world_dims);
  
  // Generate the box minimum.
  float3 MRBox_min = newAtom.xyz - newAtom.w;
  MRBox_min -= float3(args.world_origin);
  MRBox_min /= 0.25;
  ushort3 box_min;
  {
    short3 s_min = short3(MRBox_min);
    s_min = clamp(s_min, 0, short3(grid_dims));
    box_min = ushort3(s_min);
  }
  
  // Generate the box maximum.
  float3 MRBox_max = newAtom.xyz + newAtom.w;
  MRBox_max -= float3(args.world_origin);
  MRBox_max /= 0.25;
  ushort3 box_max;
  {
    short3 s_max = short3(MRBox_max);
    s_max = clamp(s_max, 0, short3(grid_dims));
    box_max = ushort3(s_max);
  }
  
  // Transform the origin and radius.
  float3 origin = newAtom.xyz;
  origin -= float3(args.world_origin);
  origin /= 0.25;
  float radiusSquared = (newAtom.w * newAtom.w) / (0.25 * 0.25);
  
  for (ushort z = box_min[2]; z <= box_max[2]; ++z) {
    for (ushort y = box_min[1]; y <= box_max[1]; ++y) {
      for (ushort x = box_min[0]; x <= box_max[0]; ++x) {
        ushort3 cube_min { x, y, z };
        
        // Narrow down the cells with a cube-sphere intersection test.
        bool mark = cube_sphere_intersection(cube_min, origin, radiusSquared);
        if (mark) {
          ushort3 cube_min { x, y, z };
          uint address = VoxelAddress::generate(grid_dims, cube_min);
          uint offset = atomic_fetch_add(dense_grid_counters + address, 1);
          
          if (offset < dense_grid_reference_capacity) {
            references[offset] = uint(tid);
          }
        }
      }
    }
  }
}
