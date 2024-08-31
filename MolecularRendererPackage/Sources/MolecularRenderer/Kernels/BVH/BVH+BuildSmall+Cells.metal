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
 device uint3 *smallCellDispatchArguments4x4x4 [[buffer(4)]],
 device uint *atomCount [[buffer(5)]],
 device uint3 *atomDispatchArguments128x1x1 [[buffer(6)]])
{
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
    *smallCellDispatchArguments4x4x4 = uint3(2 * largeVoxelCount);
  }
  
  {
    // Read the atom counts.
    uint3 globalCounts = *allocatedMemory;
    uint largeReferenceCount = globalCounts[1];
    
    // Set the atom count.
    *atomCount = largeReferenceCount;
    
    // Set the atom dispatch arguments.
    uint groupCount = (largeReferenceCount + 127) / 128;
    *atomDispatchArguments128x1x1 = uint3(groupCount, 1, 1);
  }
}

kernel void buildSmallPart1_0
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device uint *smallCounterMetadata [[buffer(1)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]])
{
  // Locate the counter metadata.
  ushort3 cellCoordinates = thread_id;
  cellCoordinates += tgid * ushort3(4, 4, 4);
  ushort3 gridDims = bvhArgs->smallVoxelCount;
  uint cellAddress = VoxelAddress::generate(gridDims, cellCoordinates);
  
  // Write the counter metadata.
  uint resetValue = uint(0);
  smallCounterMetadata[cellAddress] = resetValue;
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
 device uint *smallCounterMetadata [[buffer(2)]],
 device uint *smallCellMetadata [[buffer(3)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Locate the counter metadata.
  ushort3 cellCoordinates = thread_id;
  cellCoordinates += tgid * ushort3(4, 4, 4);
  ushort3 gridDims = bvhArgs->smallVoxelCount;
  uint cellAddress = VoxelAddress::generate(gridDims, cellCoordinates);
  
  // Read the counter metadata.
  uint threadCount = smallCounterMetadata[cellAddress];
  
  // Reduce across the SIMD.
  uint threadOffset = simd_prefix_exclusive_sum(threadCount);
  uint simdCount = simd_broadcast(threadOffset + threadCount, 31);
  
  // Reduce across the entire group.
  constexpr uint simdsPerGroup = 2;
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
  threadgroup_barrier(mem_flags::mem_threadgroup);
  threadOffset += simdOffsets[simd_id];
  
  // Store the thread metadata.
  {
    uint countPart = reverse_bits(threadCount) & voxel_count_mask;
    uint offsetPart = threadOffset & voxel_offset_mask;
    uint metadata = countPart | offsetPart;
    smallCellMetadata[cellAddress] = metadata;
  }
  
  // Store the counter metadata.
  smallCounterMetadata[cellAddress] = threadOffset;
}
