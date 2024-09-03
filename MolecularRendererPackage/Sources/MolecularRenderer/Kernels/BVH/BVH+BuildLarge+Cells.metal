//
//  BVH+BuildLarge+Cells.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/30/24.
//

#include <metal_stdlib>
#include "../Utilities/VoxelAddress.metal"
using namespace metal;

kernel void buildLargePart1_0
(
 device uchar *previousCellGroupMarks [[buffer(0)]],
 device uchar *currentCellGroupMarks [[buffer(1)]],
 device vec<uint, 8> *largeCounterMetadata [[buffer(2)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]])
{
  // Read the previous mark.
  uchar previousMark;
  {
    // Locate the mark.
    ushort3 cellCoordinates = tgid;
    uint address = VoxelAddress::generate(16, cellCoordinates);
    
    // Read the mark.
    previousMark = previousCellGroupMarks[address];
  }
  
  // Reset the current mark.
  {
    // Locate the mark.
    ushort3 cellCoordinates = tgid;
    uint address = VoxelAddress::generate(16, cellCoordinates);
    
    // Write the mark.
    uchar resetValue = uchar(0);
    currentCellGroupMarks[address] = resetValue;
  }
  
  // Reset the counter metadata.
  if (previousMark > 0) {
    // Locate the metadata.
    ushort3 cellCoordinates = thread_id;
    cellCoordinates += tgid * 4;
    uint address = VoxelAddress::generate(64, cellCoordinates);
    
    // Write the metadata.
    vec<uint, 8> resetValue = vec<uint, 8>(0);
    largeCounterMetadata[address] = resetValue;
  }
}

kernel void buildLargePart2_0
(
 device uint3 *allocatedMemory [[buffer(0)]],
 device int3 *boundingBoxMin [[buffer(1)]],
 device int3 *boundingBoxMax [[buffer(2)]])
{
  // The first three slots are allocators. We initialize them with the smallest
  // acceptable pointer value.
  // - Large voxel count.
  // - Large reference count.
  // - Small reference count.
  uint3 smallestPointer = uint3(1);
  allocatedMemory[0] = smallestPointer;
  
  // Next, is the bounding box counter.
  // - Minimum: initial value is +64 nm.
  // - Maximum: initial value is -64 nm.
  int3 boxMin = int3(64);
  int3 boxMax = int3(-64);
  boundingBoxMin[0] = boxMin;
  boundingBoxMax[0] = boxMax;
}

// Inputs:
// - largeInputMetadata (8x duplicate)
//   - large refcount (14 bits), small refcount (18 bits)
//
// Outputs:
// - largeInputMetadata (8x duplicate)
//   - large reference offset
// - largeOutputMetadata
//   - compacted large voxel offset
//   - large reference offset
//   - small reference offset
//   - atom count
// - amount of memory allocated
// - compact bounding box for dense DDA traversal
kernel void buildLargePart2_1
(
 device atomic_uint *allocatedMemory [[buffer(0)]],
 device atomic_int *boundingBoxMin [[buffer(1)]],
 device atomic_int *boundingBoxMax [[buffer(2)]],
 device uchar *currentCellGroupMarks [[buffer(3)]],
 device vec<uint, 8> *largeCounterMetadata [[buffer(4)]],
 device uint4 *largeCellMetadata [[buffer(5)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Read the current mark.
  uchar currentMark;
  {
    // Locate the mark.
    ushort3 cellCoordinates = tgid;
    uint address = VoxelAddress::generate(16, cellCoordinates);
    
    // Read the mark.
    currentMark = currentCellGroupMarks[address];
  }
  
  // Locate the counter metadata.
  ushort3 cellCoordinates = thread_id;
  cellCoordinates += tgid * 4;
  uint cellAddress = VoxelAddress::generate(64, cellCoordinates);
  
  // Return early for vacant voxels.
  if (currentMark == 0) {
    largeCellMetadata[cellAddress] = uint4(0);
    return;
  }
  
  // Read the counter metadata.
  vec<uint, 8> counterCounts = largeCounterMetadata[cellAddress];
  
  // Reduce the counts across the thread.
  uint threadTotalCount = 0;
#pragma clang loop unroll(full)
  for (ushort laneID = 0; laneID < 8; ++laneID) {
    threadTotalCount += counterCounts[laneID];
  }
  
  // Reserve this much memory for the large voxel.
  uint3 threadCounts;
  {
    uint threadVoxelCount = (threadTotalCount > 0) ? 1 : 0;
    uint threadLargeCount = threadTotalCount & (uint(1 << 14) - 1);
    uint threadSmallCount = threadTotalCount >> 14;
    threadCounts = uint3(threadVoxelCount,
                         threadLargeCount,
                         threadSmallCount);
  }
  
  // Reduce the counts across the SIMD.
  uint3 threadOffsets = simd_prefix_exclusive_sum(threadCounts);
  uint3 simdCounts = simd_broadcast(threadOffsets + threadCounts, 31);
  
  // Reduce the bounding box across the SIMD.
  int3 threadBoxMin;
  int3 threadBoxMax;
  if (threadTotalCount > 0) {
    threadBoxMin = int3(cellCoordinates) * 2 - 64;
    threadBoxMax = threadBoxMin + 2;
  } else {
    threadBoxMin = int3(64);
    threadBoxMax = int3(-64);
  }
  int3 simdBoxMin = simd_min(threadBoxMin);
  int3 simdBoxMax = simd_max(threadBoxMax);
  
  // Reduce across the entire GPU.
  uint simdOffsetValue = 0;
  if (lane_id < 3) {
    // Distribute the data across three threads.
    uint countValue = 0;
    int boxMinValue = 64;
    int boxMaxValue = -64;
#pragma clang loop unroll(full)
    for (ushort axisID = 0; axisID < 3; ++axisID) {
      if (lane_id == axisID) {
        countValue = simdCounts[axisID];
        boxMinValue = simdBoxMin[axisID];
        boxMaxValue = simdBoxMax[axisID];
      }
    }
    
    // Allocate memory, using the global counters.
    simdOffsetValue =
    atomic_fetch_add_explicit(allocatedMemory + lane_id,
                              countValue, memory_order_relaxed);
    
    // Reduce the dense boounding box.
    atomic_fetch_min_explicit(boundingBoxMin + lane_id,
                              boxMinValue, memory_order_relaxed);
    atomic_fetch_max_explicit(boundingBoxMax + lane_id,
                              boxMaxValue, memory_order_relaxed);
  }
  
  // Add the SIMD offset to the thread offset.
  uint threadVoxelOffset = threadOffsets[0];
  uint threadLargeOffset = threadOffsets[1];
  uint threadSmallOffset = threadOffsets[2];
  threadVoxelOffset += simd_broadcast(simdOffsetValue, 0);
  threadLargeOffset += simd_broadcast(simdOffsetValue, 1);
  threadSmallOffset += simd_broadcast(simdOffsetValue, 2);
  
  // If just this thread is empty, return here.
  if (threadTotalCount == 0) {
    largeCellMetadata[cellAddress] = uint4(0);
    return;
  }
  
  // Write the cell metadata.
  {
    uint4 threadMetadata(threadVoxelOffset,
                         threadLargeOffset,
                         threadSmallOffset,
                         threadTotalCount & (uint(1 << 14) - 1));
    largeCellMetadata[cellAddress] = threadMetadata;
  }
  
  // Write the counter offsets.
  {
    vec<uint, 8> counterOffsets;
    uint counterCursor = 0;
#pragma clang loop unroll(full)
    for (ushort laneID = 0; laneID < 8; ++laneID) {
      counterOffsets[laneID] = counterCursor;
      
      uint counterCount = counterCounts[laneID];
      counterCount = counterCount & (uint(1 << 14) - 1);
      counterCursor += counterCount;
    }
    counterOffsets += threadLargeOffset;
    largeCounterMetadata[cellAddress] = counterOffsets;
  }
}
