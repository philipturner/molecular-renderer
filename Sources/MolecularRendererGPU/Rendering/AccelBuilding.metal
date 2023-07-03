//
//  AccelBuilding.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/3/23.
//

#include <metal_stdlib>
#include "MRAtom.metal"
using namespace metal;

// MARK: - Pass 1

// Cell width in nm.
constant float cell_width = 0.5;

// Set the global atomic for pass 2 exactly after the last (padded) cell of the
// grid, so they all zero out in a single call.
kernel void memset_pattern4(device void *b [[buffer(0)]],
                            constant void *pattern4 [[buffer(1)]],
                            uint tid [[thread_position_in_grid]])
{
  auto _b = (device uint*)b;
  auto _pattern4 = (constant uint*)pattern4;
  _b[tid] = _pattern4[0];
}

kernel void dense_uniform_grid_pass1
(
 constant void *args [[buffer(0)]],
 constant MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 
 texture3d<uint, access::read_write> uniform_grid [[texture(0)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom = atoms[tid];
  MRBoundingBox box = atom.getBoundingBox(styles);
  box.min /= cell_width;
  box.max /= cell_width;
  ushort3 grid_center(uniform_grid.get_width() / 2);
  
  for (float x = floor(box.min.x); x < box.max.x; ++x) {
    for (float y = floor(box.min.y); y < box.max.y; ++y) {
      for (float z = floor(box.min.z); z < box.max.z; ++z) {
        ushort3 offset(x, y, z);
        ushort3 grid_coords = grid_center + offset;
        uniform_grid.atomic_fetch_add(grid_coords, uint4{ 1 });
      }
    }
  }
}

// MARK: - Pass 2

// Max 1 million atoms/dense grid, including duplicated references.
// Max 65536 atoms/dense grid, excluding duplicated references.
constant uint cell_offset_mask = 0x000FFFFF;

// Max 4096 atoms/cell. This is stored in opposite-endian order to the offset.
constant uint cell_count_mask = 0xFFF00000;

kernel void dense_uniform_grid_pass2
(
 constant void *args [[buffer(0)]],
 
 device uint *uniform_grid [[buffer(1)]],
 device uint *next_pass_atomics [[buffer(2)]],
 device atomic_uint *global_atomic [[buffer(3)]],
 
 // 128 thread/threadgroup
 uint tid [[thread_position_in_grid]],
 ushort sidx [[simdgroup_index_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]])
{
  // Allocate extra cells if the total number isn't divisible by 128. The first
  // pass should zero them out.
  uint cell_count = uniform_grid[tid];
  uint prefix_sum_results = simd_prefix_exclusive_sum(cell_count);
  
  threadgroup uint group_results[4];
  if (lane_id == 31) {
    group_results[sidx] = prefix_sum_results + cell_count;
  }
  next_pass_atomics[tid] = 0; // Do some work while waiting.
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Prefix sum across simds.
  if (sidx == 0 && lane_id < 4) {
    uint cell_count = group_results[lane_id];
    uint prefix_sum_results = quad_prefix_exclusive_sum(cell_count);
    
    // Increment device atomic.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wuninitialized"
    uint group_offset;
    if (lane_id == 3) {
      uint total_cell_count = prefix_sum_results + cell_count;
      group_offset = atomic_fetch_add_explicit
      (
       global_atomic, total_cell_count, memory_order_relaxed);
    }
    prefix_sum_results += quad_broadcast(group_offset, 3);
#pragma clang diagnostic pop
    group_results[lane_id] = prefix_sum_results;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Overwrite contents of the texture.
  prefix_sum_results += group_results[sidx];
  uint count_part = reverse_bits(cell_count) & cell_count_mask;
  uint offset_part = prefix_sum_results & cell_offset_mask;
  uniform_grid[tid] = count_part | offset_part;
}

// MARK: - Pass 3
