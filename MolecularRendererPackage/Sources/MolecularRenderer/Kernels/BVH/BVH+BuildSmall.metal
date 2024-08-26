//
//  BVH+BuildSmall.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "../Utilities/VoxelAddress.metal"
using namespace metal;

kernel void clearSmallCellMetadata
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device uint *smallCellMetadata [[buffer(1)]],
 
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]])
{
  ushort3 coordinates = tgid * 8;
  coordinates += thread_id * ushort3(4, 1, 1);
  
  ushort3 grid_dims = bvhArgs->smallVoxelCount;
  uint address = VoxelAddress::generate(grid_dims, coordinates);
  auto pointer = (device uint4*)(smallCellMetadata + address);
  *pointer = uint4(0);
}

// Quantize a position relative to the world origin.
ushort3 quantize(float3 position, ushort3 world_dims) {
  short3 output = short3(position);
  output = clamp(output, 0, short3(world_dims));
  return ushort3(output);
}

// Test whether an atom overlaps a 1x1x1 cube.
bool cubeSphereIntersection(ushort3 cube_min, float4 atom)
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

kernel void buildSmallPart1
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device atomic_uint *smallCellMetadata [[buffer(1)]],
 device float4 *convertedAtoms [[buffer(2)]],
 
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
          // Increment the voxel's counter.
          uint address = VoxelAddress::generate(grid_dims, cube_min);
          atomic_fetch_add_explicit(smallCellMetadata + address,
                                    1, memory_order_relaxed);
        }
      }
    }
  }
}

// TODO: Reorder this, making it a 3D reduction across threads. 
// - The indices in memory are still X/Y/Z.
// - The threadgroup dispatch goes by large voxel.
// - The BVH arguments are bound to the buffer table.
// - Use "densePass2v2" until the rewritten function is fully debugged.

// TODO: Cleaning up references to SIMD ID and lane ID.
#if 1
kernel void buildSmallPart2
(
 device uint *smallCellMetadata [[buffer(0)]],
 device uint *smallCellCounters [[buffer(1)]],
 device atomic_uint *globalAtomicCounter [[buffer(2)]],
 
 // 128 threads/threadgroup
 uint tid [[thread_position_in_grid]],
 ushort sidx [[simdgroup_index_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]])
{
  uint atomCount = smallCellMetadata[tid];
  uint reducedAtomCount = simd_prefix_exclusive_sum(atomCount);
  
  threadgroup uint threadgroupAtomCount[4];
  if (lane_id == 31) {
    threadgroupAtomCount[sidx] = reducedAtomCount + atomCount;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Prefix sum across simds.
  if (sidx == 0 && lane_id < 4) {
    uint atomCount = threadgroupAtomCount[lane_id];
    uint reducedAtomCount = quad_prefix_exclusive_sum(atomCount);
    
    // Increment device atomic.
    uint globalOffset;
    if (lane_id == 3) {
      uint totalAtomCount = reducedAtomCount + atomCount;
      globalOffset =
      atomic_fetch_add_explicit(globalAtomicCounter,
                                totalAtomCount, memory_order_relaxed);
    } else {
      globalOffset = 0;
    }
    reducedAtomCount += quad_broadcast(globalOffset, 3);
    threadgroupAtomCount[lane_id] = reducedAtomCount;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  reducedAtomCount += threadgroupAtomCount[sidx];
  reducedAtomCount = min(reducedAtomCount, dense_grid_reference_capacity);
  
  uint nextCellOffset = reducedAtomCount + atomCount;
  nextCellOffset = min(nextCellOffset, dense_grid_reference_capacity);
  atomCount = nextCellOffset - reducedAtomCount;
  
  // Overwrite contents of the grid.
  uint count_part = reverse_bits(atomCount) & voxel_count_mask;
  uint offset_part = reducedAtomCount & voxel_offset_mask;
  smallCellMetadata[tid] = count_part | offset_part;
  smallCellCounters[tid] = reducedAtomCount;
}
#else

kernel void buildSmallPart2
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device uint *smallCellMetadata [[buffer(1)]],
 device uint *smallCellCounters [[buffer(2)]],
 device atomic_uint *globalAtomicCounter [[buffer(3)]],
 
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Load the small-cell atom counts.
  uint4 cellAtomCounts;
  {
    ushort3 coordinates = tgid * 8;
    coordinates += thread_id * ushort3(4, 1, 1);
    
    ushort3 grid_dims = bvhArgs->smallVoxelCount;
    uint address = VoxelAddress::generate(grid_dims, coordinates);
    auto pointer = (device uint4*)(smallCellMetadata + address);
    cellAtomCounts = *pointer;
  }
  
  // Reduce across the thread.
  uint4 cellAtomOffsets;
  cellAtomOffsets[0] = 0;
  cellAtomOffsets[1] = cellAtomOffsets[0] + cellAtomCounts[0];
  cellAtomOffsets[2] = cellAtomOffsets[1] + cellAtomCounts[1];
  cellAtomOffsets[3] = cellAtomOffsets[2] + cellAtomCounts[2];
  
  // Reduce across the SIMD.
  uint simdAtomCount;
  {
    uint threadAtomCount = cellAtomOffsets[3] + cellAtomOffsets[3];
    uint threadAtomOffset = simd_prefix_exclusive_sum(threadAtomCount);
    simdAtomCount = simd_broadcast(threadAtomOffset + threadAtomCount, 31);
    cellAtomOffsets += threadAtomOffset;
  }
  
  // Reduce across the threadgroup.
  threadgroup uint threadgroupCellCounts[4];
  threadgroup uint threadgroupCellOffsets[4];
  if (lane_id == 0) {
    threadgroupCellCounts[simd_id] = simdAtomCount;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Reduce across the SIMD.
  if (simd_id == 0) {
    
  }
}
#endif

kernel void buildSmallPart3
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device atomic_uint *smallCellCounters [[buffer(1)]],
 device uint *smallCellAtomReferences [[buffer(2)]],
 device float4 *convertedAtoms [[buffer(3)]],
 
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
          // Increment the voxel's counter.
          uint address = VoxelAddress::generate(grid_dims, cube_min);
          uint offset =
          atomic_fetch_add_explicit(smallCellCounters + address,
                                    1, memory_order_relaxed);
          
          // Write the reference to the list.
          if (offset < dense_grid_reference_capacity) {
            smallCellAtomReferences[offset] = uint(tid);
          }
        }
      }
    }
  }
}
