//
//  BVH+BuildLarge+Cells.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/30/24.
//

#include <metal_stdlib>
#include "../Utilities/VoxelAddress.metal"
#include "../Utilities/WorldVolume.metal"
using namespace metal;

// Before optimizations: 42 μs
//                       42 μs
kernel void buildLargePart1_0
(
 device uchar *previousCellGroupMarks [[buffer(0)]],
 device uchar *currentCellGroupMarks [[buffer(1)]],
 device vec<uint, 8> *largeCounterMetadata [[buffer(2)]],
 device uint4 *largeCellMetadata [[buffer(3)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]])
{
  uchar previousMark;
  {
    // Locate the mark.
    ushort3 cellCoordinates = tgid;
    uint address = VoxelAddress::generate(largeVoxelGridWidth / 4,
                                          cellCoordinates);
    
    // Read the previous mark.
    previousMark = previousCellGroupMarks[address];
    
    // Write the current mark.
    uchar resetValue = uchar(0);
    currentCellGroupMarks[address] = resetValue;
  }
  
  if (previousMark > 0) {
    // Locate the metadata.
    ushort3 cellCoordinates = thread_id;
    cellCoordinates += tgid * 4;
    uint address = VoxelAddress::generate(largeVoxelGridWidth,
                                          cellCoordinates);
    
    // Write the large counter metadata.
    {
      vec<uint, 8> resetValue = vec<uint, 8>(0);
      largeCounterMetadata[address] = resetValue;
    }
    
    // Write the large cell metadata.
    {
      uint4 resetValue = uint4(0);
      largeCellMetadata[address] = resetValue;
    }
  }
}

kernel void buildLargePart2_0
(
 device uint3 *allocatedMemory [[buffer(0)]])
{
  // The first three slots are allocators. We initialize them with the smallest
  // acceptable pointer value.
  // - Large voxel count.
  // - Large reference count.
  // - Small reference count.
  uint3 smallestPointer = uint3(1);
  allocatedMemory[0] = smallestPointer;
}

// Before optimizations: 367 μs
//                       309 μs
//
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
 device uchar *currentCellGroupMarks [[buffer(1)]],
 device vec<uint, 8> *largeCounterMetadata [[buffer(2)]],
 device uint4 *largeCellMetadata [[buffer(3)]],
 device uint4 *compactedLargeCellMetadata [[buffer(4)]],
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
    uint address = VoxelAddress::generate(largeVoxelGridWidth / 4,
                                          cellCoordinates);
    
    // Read the mark.
    currentMark = currentCellGroupMarks[address];
  }
  
  // Locate the counter metadata.
  uint largeCellAddress;
  {
    ushort3 cellCoordinates = thread_id;
    cellCoordinates += tgid * 4;
    largeCellAddress = VoxelAddress::generate(largeVoxelGridWidth,
                                              cellCoordinates);
  }
  
  // Return early for vacant voxels.
  if (currentMark == 0) {
    largeCellMetadata[largeCellAddress] = uint4(0);
    return;
  }
  
  // Read the counter metadata.
  vec<uint, 8> counterCounts = largeCounterMetadata[largeCellAddress];
  
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
  
  // Reduce across the entire GPU.
  uint simdOffsetValue = 0;
  if (lane_id < 3) {
    // Distribute the data across three threads.
    uint countValue = 0;
#pragma clang loop unroll(full)
    for (ushort axisID = 0; axisID < 3; ++axisID) {
      if (lane_id == axisID) {
        countValue = simdCounts[axisID];
      }
    }
    
    // Allocate memory, using the global counters.
    simdOffsetValue =
    atomic_fetch_add_explicit(allocatedMemory + lane_id,
                              countValue, memory_order_relaxed);
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
    largeCellMetadata[largeCellAddress] = uint4(0);
    return;
  }
  
  // Write the cell metadata.
  {
    uint4 threadMetadata(threadVoxelOffset,
                         threadLargeOffset,
                         threadSmallOffset,
                         threadTotalCount & (uint(1 << 14) - 1));
    largeCellMetadata[largeCellAddress] = threadMetadata;
    
    ushort3 cellCoordinates = thread_id;
    cellCoordinates += tgid * 4;
    uchar4 compressedCellCoordinates(uchar3(cellCoordinates), 0);
    threadMetadata[0] = as_type<uint>(compressedCellCoordinates);
    compactedLargeCellMetadata[threadVoxelOffset] = threadMetadata;
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
    largeCounterMetadata[largeCellAddress] = counterOffsets;
  }
}
