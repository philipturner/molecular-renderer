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
 device uint3 *atomDispatchArguments8x8x8 [[buffer(4)]])
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
  
  // Set the BVH arguments.
  bvhArgs->worldMinimum = float3(minimum);
  bvhArgs->worldMaximum = float3(maximum);
  bvhArgs->largeVoxelCount = largeVoxelCount;
  bvhArgs->smallVoxelCount = largeVoxelCount * 8;
  
  // Set the atom dispatch arguments.
  *atomDispatchArguments8x8x8 = uint3(largeVoxelCount);
}

kernel void buildSmallPart1_0
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device uint *smallCounterMetadata [[buffer(1)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]])
{
  // Locate the counter metadata.
  ushort3 cellCoordinates = thread_id * ushort3(4, 1, 1);
  cellCoordinates += tgid * 8;
  ushort3 gridDims = bvhArgs->smallVoxelCount;
  uint baseAddress = VoxelAddress::generate(gridDims, cellCoordinates);
  
  // Write the counter metadata.
#pragma clang loop unroll(full)
  for (ushort laneID = 0; laneID < 4; ++laneID) {
    uint cellAddress = baseAddress + laneID;
    uint resetValue = uint(0);
    smallCounterMetadata[cellAddress] = resetValue;
  }
}

kernel void buildSmallPart2_0
(
 device uint *allocatedMemory [[buffer(0)]])
{
  // TODO: Fuse this with buildSmallPart0_0.
  
  // Initialize with the smallest acceptable pointer value.
  uint smallestPointer = uint(1);
  allocatedMemory[0] = smallestPointer;
}

kernel void buildSmallPart2_1
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device atomic_uint *allocatedMemory [[buffer(1)]],
 device uint *smallCounterMetadata [[buffer(2)]],
 device uint *smallCellMetadata [[buffer(3)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Locate the counter metadata.
  ushort3 cellCoordinates = thread_id * ushort3(4, 1, 1);
  cellCoordinates += tgid * 8;
  ushort3 gridDims = bvhArgs->smallVoxelCount;
  uint baseAddress = VoxelAddress::generate(gridDims, cellCoordinates);
  
  // Read the counter metadata.
  uint4 counterCounts;
#pragma clang loop unroll(full)
  for (ushort laneID = 0; laneID < 4; ++laneID) {
    uint cellAddress = baseAddress + laneID;
    uint count = smallCounterMetadata[cellAddress];
    counterCounts[laneID] = count;
  }
  
  // Reduce across the thread.
  uint4 counterOffsets;
  uint threadCount = 0;
#pragma clang loop unroll(full)
  for (ushort laneID = 0; laneID < 4; ++laneID) {
    uint counterOffset = threadCount;
    threadCount += counterCounts[laneID];
    counterOffsets[laneID] = counterOffset;
  }
  
  // Reduce across the SIMD.
  uint threadOffset = simd_prefix_exclusive_sum(threadCount);
  uint simdCount = simd_broadcast(threadOffset + threadCount, 31);
  
  // Reduce across the entire group.
  constexpr uint simdsPerGroup = 4;
  threadgroup uint simdCounts[simdsPerGroup];
  if (lane_id == 0) {
    simdCounts[simd_id] = simdCount;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Reduce across the entire GPU.
  threadgroup uint simdOffsets[simdsPerGroup];
  if (simd_id == 0) {
    uint simdCount = simdCounts[lane_id % simdsPerGroup];
    uint simdOffset = simd_prefix_exclusive_sum(simdCount);
    uint groupCount = simd_broadcast(simdOffset + simdCount, simdsPerGroup - 1);
    
    // This part may be a parallelization bottleneck on large GPUs.
    uint groupOffset = 0;
    if (lane_id == 0) {
      groupOffset = atomic_fetch_add_explicit(allocatedMemory,
                                              groupCount,
                                              memory_order_relaxed);
    }
    groupOffset = simd_broadcast(groupOffset, 0);
    
    // Add the group offset to the SIMD offset.
    if (lane_id < simdsPerGroup) {
      simdOffset += groupOffset;
      simdOffsets[lane_id] = simdOffset;
    }
  }
  
  // Add the SIMD offset to the thread offset.
  // Add the thread offset to the cell offset.
  threadgroup_barrier(mem_flags::mem_threadgroup);
  threadOffset += simdOffsets[simd_id];
  counterOffsets += threadOffset;
  
  // Write the cell metadata and counter metadata.
#pragma clang loop unroll(full)
  for (ushort laneID = 0; laneID < 4; ++laneID) {
    uint count = counterCounts[laneID];
    uint offset = counterOffsets[laneID];
    uint countPart = reverse_bits(count) & voxel_count_mask;
    uint offsetPart = offset & voxel_offset_mask;
    uint metadata = countPart | offsetPart;
    
    uint cellAddress = baseAddress + laneID;
    smallCellMetadata[cellAddress] = metadata;
    smallCounterMetadata[cellAddress] = offset;
  }
}
