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

kernel void dense_grid_pass1
(
 constant uniform_grid_arguments &args [[buffer(0)]],
 constant MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 device atomic_uint *dense_grid_data [[buffer(3)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom = atoms[tid];
  MRBoundingBox box = atom.getBoundingBox(styles);
  box.min /= cell_width;
  box.max /= cell_width;
  
  DenseGrid grid(args.grid_width);
  box.min = grid.apply_offset(box.min);
  box.max = grid.apply_offset(box.max);
  
  // Sparse grids: assume the atom doesn't intersect more than 8 dense grids.
  for (float x = floor(box.min.x); x < box.max.x; ++x) {
    for (float y = floor(box.min.y); y < box.max.y; ++y) {
      for (float z = floor(box.min.z); z < box.max.z; ++z) {
        float3 coords(x, y, z);
        grid.increment(dense_grid_data, coords);
      }
    }
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
  uint cell_count = dense_grid_data[tid];
  uint prefix_sum_results = simd_prefix_exclusive_sum(cell_count);
  
  threadgroup uint group_results[4];
  if (lane_id == 31) {
    group_results[sidx] = prefix_sum_results + cell_count;
  }
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
       global_counter, total_cell_count, memory_order_relaxed);
    }
    prefix_sum_results += quad_broadcast(group_offset, 3);
#pragma clang diagnostic pop
    group_results[lane_id] = prefix_sum_results;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Overwrite contents of the grid.
  prefix_sum_results += group_results[sidx];
  uint count_part = reverse_bits(cell_count) & cell_count_mask;
  uint offset_part = prefix_sum_results & cell_offset_mask;
  dense_grid_data[tid] = count_part | offset_part;
  dense_grid_counters[tid] = prefix_sum_results;
}

// MARK: - Pass 3

kernel void dense_grid_pass3
(
 constant uniform_grid_arguments &args [[buffer(0)]],
 constant MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 
 device atomic_uint *dense_grid_counters [[buffer(4)]],
 device ushort *references [[buffer(6)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom = atoms[tid];
  MRBoundingBox box = atom.getBoundingBox(styles);
  box.min /= cell_width;
  box.max /= cell_width;
  
  DenseGrid grid(args.grid_width);
  box.min = grid.apply_offset(box.min);
  box.max = grid.apply_offset(box.max);
  
  // Sparse grids: assume the atom doesn't intersect more than 8 dense grids.
  for (float x = floor(box.min.x); x < box.max.x; ++x) {
    for (float y = floor(box.min.y); y < box.max.y; ++y) {
      for (float z = floor(box.min.z); z < box.max.z; ++z) {
        float3 coords(x, y, z);
        uint offset = grid.increment(dense_grid_counters, coords);
        references[offset] = ushort(tid);
      }
    }
  }
}
