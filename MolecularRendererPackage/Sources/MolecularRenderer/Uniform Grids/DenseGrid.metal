//
//  DenseGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
//

#include <metal_stdlib>
#include "../Utilities/Atomic.metal"
#include "UniformGrid.metal"
using namespace metal;

#define DENSE_BOX_GENERATE(EXTREMUM) \
box.EXTREMUM -= float3(args.world_origin); \
box.EXTREMUM /= 0.25; \
ushort3 box_##EXTREMUM; \
{\
short3 s_##EXTREMUM = short3(box.EXTREMUM); \
s_##EXTREMUM = clamp(s_##EXTREMUM, 0, short3(grid_dims)); \
box_##EXTREMUM = ushort3(s_##EXTREMUM); \
}\

#define DENSE_BOX_LOOP(COORD) \
for (ushort COORD = box_min.COORD; COORD <= box_max.COORD; ++COORD) \

struct Box {
  float3 min;
  float3 max;
};

struct DenseGridArguments {
  short3 world_origin;
  short3 world_dims;
  ushort cell_sphere_test;
};

// MARK: - Pass 1

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

kernel void dense_grid_pass1
(
 constant DenseGridArguments &args [[buffer(0)]],
 const device MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 device atomic_uint *dense_grid_data [[buffer(3)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom(atoms + tid);
  MRBoundingBox box = atom.getBoundingBox(styles);
  ushort3 grid_dims = ushort3(4 * args.world_dims);
  half3 h_grid_dims = half3(4 * args.world_dims);
  DENSE_BOX_GENERATE(min)
  DENSE_BOX_GENERATE(max)
  
  float3 origin = atom.origin / 0.25;
  origin += float3(h_grid_dims) * 0.5;
  float radiusSquared = atom.radiusSquared / (0.25 * 0.25);
  
  // Sparse grids: assume the atom doesn't intersect more than 8 dense grids.
  uint address_z = VoxelAddress::generate(grid_dims, box_min);
  DENSE_BOX_LOOP(z) {
    uint address_y = address_z;
    DENSE_BOX_LOOP(y) {
      uint address_x = address_y;
      DENSE_BOX_LOOP(x) {
        bool mark = true;
        if (args.cell_sphere_test) {
          mark = cube_sphere_intersection({ x, y, z }, origin, radiusSquared);
        }
        if (mark) {
          atomic_fetch_add(dense_grid_data + address_x, 1);
        }
        address_x += VoxelAddress::increment_x(grid_dims);
      }
      address_y += VoxelAddress::increment_y(grid_dims);
    }
    address_z += VoxelAddress::increment_z(grid_dims);
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
 const device MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 
 device atomic_uint *dense_grid_counters [[buffer(4)]],
 device uint *references [[buffer(6)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom(atoms + tid);
  MRBoundingBox box = atom.getBoundingBox(styles);
  ushort3 grid_dims = ushort3(4 * args.world_dims);
  half3 h_grid_dims = half3(4 * args.world_dims);
  DENSE_BOX_GENERATE(min)
  DENSE_BOX_GENERATE(max)
  
  float3 origin = atom.origin / 0.25;
  origin += float3(h_grid_dims) * 0.5;
  float radiusSquared = atom.radiusSquared / (0.25 * 0.25);
  
  // Sparse grids: assume the atom doesn't intersect more than 8 dense grids.
  uint address_z = VoxelAddress::generate(grid_dims, box_min);
  DENSE_BOX_LOOP(z) {
    uint address_y = address_z;
    DENSE_BOX_LOOP(y) {
      uint address_x = address_y;
      DENSE_BOX_LOOP(x) {
        bool mark = true;
        if (args.cell_sphere_test) {
          mark = cube_sphere_intersection({ x, y, z }, origin, radiusSquared);
        }
        if (mark) {
          uint offset =
          atomic_fetch_add(dense_grid_counters + address_x, 1);
          
          if (offset < dense_grid_reference_capacity) {
            references[offset] = uint(tid);
          }
        }
        address_x += VoxelAddress::increment_x(grid_dims);
      }
      address_y += VoxelAddress::increment_y(grid_dims);
    }
    address_z += VoxelAddress::increment_z(grid_dims);
  }
}

