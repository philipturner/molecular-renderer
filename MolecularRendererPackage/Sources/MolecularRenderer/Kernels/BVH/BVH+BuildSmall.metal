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
 device uint4 *smallCellMetadata [[buffer(1)]],
 
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]])
{
  ushort3 cellCoordinates = tgid * 8;
  cellCoordinates += thread_id * ushort3(4, 1, 1);
  uint cellAddress = VoxelAddress::generate(bvhArgs->smallVoxelCount,
                                            cellCoordinates);
  smallCellMetadata[cellAddress / 4] = uint4(0);
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

#if 0
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
 device uint4 *smallCellMetadata [[buffer(1)]],
 device uint4 *smallCellCounters [[buffer(2)]],
 device atomic_uint *globalAtomicCounter [[buffer(3)]],
 
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Load the cell atom counts.
  ushort3 cellCoordinates = tgid * 8;
  cellCoordinates += thread_id * ushort3(4, 1, 1);
  uint cellAddress = VoxelAddress::generate(bvhArgs->smallVoxelCount,
                                            cellCoordinates);
  uint4 cellAtomCounts = smallCellMetadata[cellAddress / 4];
  
  // Reduce across the thread.
  uint4 cellAtomOffsets;
  cellAtomOffsets[0] = 0;
  cellAtomOffsets[1] = cellAtomOffsets[0] + cellAtomCounts[0];
  cellAtomOffsets[2] = cellAtomOffsets[1] + cellAtomCounts[1];
  cellAtomOffsets[3] = cellAtomOffsets[2] + cellAtomCounts[2];
  uint threadAtomCount = cellAtomOffsets[3] + cellAtomCounts[3];
  
  // Reduce across the SIMD.
  uint threadAtomOffset = simd_prefix_exclusive_sum(threadAtomCount);
  uint simdAtomCount = simd_broadcast(threadAtomOffset + threadAtomCount, 31);
  
  // Reduce across the entire group.
  threadgroup uint simdAtomCounts[4];
  if (lane_id == 0) {
    simdAtomCounts[simd_id] = simdAtomCount;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Reduce across the entire GPU.
  threadgroup uint simdAtomOffsets[4];
  if (simd_id == 0) {
    uint simdAtomCount = simdAtomCounts[lane_id % 4];
    uint simdAtomOffset = simd_prefix_exclusive_sum(simdAtomCount);
    uint groupAtomCount = simd_broadcast(simdAtomOffset + simdAtomCount, 3);
    
    // This part may be a parallelization bottleneck on large GPUs.
    uint groupAtomOffset = 0;
    if (lane_id == 0) {
      groupAtomOffset =
      atomic_fetch_add_explicit(globalAtomicCounter,
                                groupAtomCount, memory_order_relaxed);
    }
    
#if 0
    groupAtomOffset = simd_broadcast(groupAtomOffset, 0);
    
    // Add the group offset to the SIMD offset.
    if (lane_id < 3) {
      simdAtomOffset += groupAtomOffset;
      simdAtomOffsets[lane_id] = simdAtomOffset;
    }
#endif
  }
  
#if 0
  
  // Add the SIMD offset to the thread offset.
  threadgroup_barrier(mem_flags::mem_threadgroup);
  threadAtomOffset += simdAtomOffsets[lane_id];
  cellAtomOffsets += threadAtomOffset;
  
  // Encode the offset and count into a single word.
  uint4 cellMetadata = uint4(0);
#pragma clang loop unroll(full)
  for (uint cellID = 0; cellID < 4; ++cellID) {
    uint atomOffset = cellAtomOffsets[cellID];
    uint atomCount = cellAtomCounts[cellID];
    if (atomOffset + atomCount > dense_grid_reference_capacity) {
      atomOffset = 0;
      atomCount = 0;
    }
    
    uint countPart = reverse_bits(atomCount) & voxel_count_mask;
    uint offsetPart = atomOffset & voxel_offset_mask;
    uint metadata = countPart | offsetPart;
    cellMetadata[cellID] = metadata;
  }
  
  // Store the result to memory.
  smallCellMetadata[cellAddress / 4] = cellMetadata;
  smallCellCounters[cellAddress / 4] = cellAtomOffsets;
  
#endif
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
