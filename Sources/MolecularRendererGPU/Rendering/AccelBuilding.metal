//
//  AccelBuilding.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/3/23.
//

#include <metal_stdlib>
#include "MRAtom.metal"
#include "UniformGrid.metal"
using namespace metal;

#define ATOMIC_INCREMENT(OBJECT) \
atomic_fetch_add_explicit(OBJECT, 1, memory_order_relaxed);

#define BOX_GENERATE(EXTREMUM) \
box.EXTREMUM *= voxel_width_denom / voxel_width_numer; \
box.EXTREMUM += h_grid_width * 0.5; \
ushort3 box_##EXTREMUM; \
{\
short3 s_##EXTREMUM = short3(box.EXTREMUM); \
s_##EXTREMUM = clamp(s_##EXTREMUM, 0, grid_width); \
box_##EXTREMUM = ushort3(s_##EXTREMUM); \
}\

#define BOX_LOOP(COORD) \
for (ushort COORD = box_min.COORD; COORD <= box_max.COORD; ++COORD) \

struct uniform_grid_arguments {
  ushort grid_width;
};

// MARK: - Pass 1

constant uint pattern4 [[function_constant(10)]];

kernel void memset_pattern4
(
 device uint *b [[buffer(0)]],
 uint tid [[thread_position_in_grid]])
{
  b[tid] = pattern4;
}

struct Box {
  float3 min;
  float3 max;
};

kernel void dense_grid_pass1
(
 constant uniform_grid_arguments &args [[buffer(0)]],
 constant MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 device atomic_uint *dense_grid_data [[buffer(3)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom(atoms + tid);
  MRBoundingBox box = atom.getBoundingBox(styles);
  ushort grid_width = args.grid_width;
  half h_grid_width = args.grid_width;
  BOX_GENERATE(min)
  BOX_GENERATE(max)
  
  // Sparse grids: assume the atom doesn't intersect more than 8 dense grids.
  uint address_z = VoxelAddress::generate(grid_width, box_min);
  BOX_LOOP(z) {
    uint address_y = address_z;
    BOX_LOOP(y) {
      uint address_x = address_y;
      BOX_LOOP(x) {
        ATOMIC_INCREMENT(dense_grid_data + address_x);
        address_x += VoxelAddress::increment_x(grid_width);
      }
      address_y += VoxelAddress::increment_y(grid_width);
    }
    address_z += VoxelAddress::increment_z(grid_width);
  }
}

// MARK: - Pass 2

kernel void dense_grid_pass2
(
 constant uniform_grid_arguments &args [[buffer(0)]],
 device uint *dense_grid_data [[buffer(3)]],
 device uint *dense_grid_counters [[buffer(4)]],
 device atomic_uint *global_counter [[buffer(5)]],
 
 // 128 thread/threadgroup
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
  
  // Overwrite contents of the grid.
  prefix_sum_results += group_results[sidx];
  uint count_part = reverse_bits(voxel_count) & voxel_count_mask;
  uint offset_part = prefix_sum_results & voxel_offset_mask;
  dense_grid_data[tid] = count_part | offset_part;
  dense_grid_counters[tid] = prefix_sum_results;
}

// MARK: - Pass 3

kernel void dense_grid_pass3
(
 constant uniform_grid_arguments &args [[buffer(0)]],
 constant MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 
 device uint *dense_grid_data [[buffer(3)]],
 device atomic_uint *dense_grid_counters [[buffer(4)]],
 device ushort *references [[buffer(6)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom(atoms + tid);
  MRBoundingBox box = atom.getBoundingBox(styles);
  ushort grid_width = args.grid_width;
  half h_grid_width = args.grid_width;
  BOX_GENERATE(min)
  BOX_GENERATE(max)
  
  // Sparse grids: assume the atom doesn't intersect more than 8 dense grids.
  uint address_z = VoxelAddress::generate(grid_width, box_min);
  BOX_LOOP(z) {
    uint address_y = address_z;
    BOX_LOOP(y) {
      uint address_x = address_y;
      BOX_LOOP(x) {
        uint offset = ATOMIC_INCREMENT(dense_grid_counters + address_x);
        references[offset] = ushort(tid);
        address_x += VoxelAddress::increment_x(grid_width);
      }
      address_y += VoxelAddress::increment_y(grid_width);
    }
    address_z += VoxelAddress::increment_z(grid_width);
  }
}
