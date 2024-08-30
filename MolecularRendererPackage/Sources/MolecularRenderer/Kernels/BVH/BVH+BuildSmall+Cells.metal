//
//  BVH+BuildSmall+Cells.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/30/24.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "../Utilities/VoxelAddress.metal"
using namespace metal;

kernel void buildSmallPart0_0
(
 device uint3 *allocatedMemory [[buffer(0)]],
 device int3 *boundingBoxMin [[buffer(1)]],
 device int3 *boundingBoxMax [[buffer(2)]],
 device BVHArguments *bvhArgs [[buffer(3)]],
 device uint3 *smallCellDispatchArguments8x8x8 [[buffer(4)]])
{
  // Read the bounding box.
  int3 minimum = *boundingBoxMin;
  int3 maximum = *boundingBoxMax;
  
  // Clamp the bounding box to the world volume.
  minimum = max(minimum, -64);
  maximum = min(maximum, 64);
  maximum = max(minimum, maximum);
  
  // Compute the grid dimensions.
  ushort3 largeVoxelCount = ushort3((maximum - minimum) / 2);
  ushort3 smallVoxelCount = ushort3(4 * (maximum - minimum));
  
  // Set the BVH arguments.
  bvhArgs->worldMinimum = float3(minimum);
  bvhArgs->worldMaximum = float3(maximum);
  bvhArgs->largeVoxelCount = largeVoxelCount;
  bvhArgs->smallVoxelCount = smallVoxelCount;
  
  // Set the small-cell dispatch arguments.
  *smallCellDispatchArguments8x8x8 = uint3(largeVoxelCount);
}

kernel void buildSmallPart1_0
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device uint4 *smallCounterMetadata [[buffer(1)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]])
{
  // Load the counter metadata.
  ushort3 cellCoordinates = tgid * 8;
  cellCoordinates += thread_id * ushort3(4, 1, 1);
  uint cellAddress = VoxelAddress::generate(bvhArgs->smallVoxelCount,
                                            cellCoordinates);
  
  // Write the counter metadata.
  uint4 resetValue = uint4(0);
  smallCounterMetadata[cellAddress / 4] = resetValue;
}

kernel void buildSmallPart2_0
(
 device uint *allocatedMemory [[buffer(0)]])
{
  // Initialize with the smallest acceptable pointer value.
  uint smallestPointer = uint(1);
  allocatedMemory[0] = smallestPointer;
}

kernel void buildSmallPart2_1
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device atomic_uint *allocatedMemory [[buffer(1)]],
 device uint4 *smallCounterMetadata [[buffer(2)]],
 device uint4 *smallCellMetadata [[buffer(3)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Locate the counter metadata.
  ushort3 cellCoordinates = tgid * 8;
  cellCoordinates += thread_id * ushort3(4, 1, 1);
  uint cellAddress = VoxelAddress::generate(bvhArgs->smallVoxelCount,
                                            cellCoordinates);
  
  // Read the counter metadata.
  uint4 cellAtomCounts = smallCounterMetadata[cellAddress / 4];
  
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
      groupAtomOffset = atomic_fetch_add_explicit(allocatedMemory,
                                                  groupAtomCount,
                                                  memory_order_relaxed);
    }
    groupAtomOffset = simd_broadcast(groupAtomOffset, 0);
    
    // Add the group offset to the SIMD offset.
    if (lane_id < 4) {
      simdAtomOffset += groupAtomOffset;
      simdAtomOffsets[lane_id] = simdAtomOffset;
    }
  }
  
  // Add the SIMD offset to the thread offset.
  threadgroup_barrier(mem_flags::mem_threadgroup);
  threadAtomOffset += simdAtomOffsets[simd_id];
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
  smallCounterMetadata[cellAddress / 4] = cellAtomOffsets;
  smallCellMetadata[cellAddress / 4] = cellMetadata;
}
