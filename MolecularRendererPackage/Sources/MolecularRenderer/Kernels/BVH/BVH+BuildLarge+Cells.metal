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

kernel void buildLargePart0_0
(
 device uint3 *allocatedMemory [[buffer(0)]],
 device uint3 *boundingBox [[buffer(1)]],
 device uchar *cellGroupMarks [[buffer(2)]],
 ushort3 tid [[thread_position_in_grid]])
{
  // A sub-section of the threads prepares the bounding box.
  if (all(tid == 0)) {
    // Write the smallest valid pointer.
    uint3 smallestPointer = uint3(1);
    allocatedMemory[0] = smallestPointer;
    
    // Prepare the bounding box counters.
    uint3 boxMinimum = uint3(cellGroupGridWidth);
    uint3 boxMaximum = uint3(0);
    boundingBox[0] = boxMinimum;
    boundingBox[1] = boxMaximum;
  }
  
  // Locate the mark.
  ushort3 cellCoordinates = tid;
  uint address = VoxelAddress::generate(cellGroupGridWidth,
                                        cellCoordinates);
  
  // Write the mark.
  uchar resetValue = uchar(0);
  cellGroupMarks[address] = resetValue;
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
kernel void buildLargePart1_0
(
 device atomic_uint *allocatedMemory [[buffer(0)]],
 device atomic_uint *boundingBox [[buffer(1)]],
 device uchar *cellGroupMarks [[buffer(2)]],
 device vec<uint, 8> *largeCounterMetadata [[buffer(3)]],
 device uint *largeCellOffsets [[buffer(4)]],
 device uint4 *compactedLargeCellMetadata [[buffer(5)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort3 tid [[thread_position_in_grid]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // A sub-section of the threads accumulates the bounding box.
  if (all(tid < cellGroupGridWidth)) {
    // Locate the mark.
    uint address = VoxelAddress::generate(cellGroupGridWidth, tid);
    
    // Read the current mark.
    uchar mark = cellGroupMarks[address];
    
    // Generate the thread's contributions to the bounding box.
    ushort3 boxMinimum = ushort3(cellGroupGridWidth);
    ushort3 boxMaximum = ushort3(0);
    boxMinimum = select(boxMinimum, tid, mark > 0);
    boxMaximum = select(boxMaximum, tid + 1, mark > 0);
    
    // Reduce across the SIMD.
    boxMinimum = simd_min(boxMinimum);
    boxMaximum = simd_max(boxMaximum);
    
    // Distribute the data across three threads.
    ushort minimumValue = ushort(cellGroupGridWidth);
    ushort maximumValue = ushort(0);
#pragma clang loop unroll(full)
    for (ushort axisID = 0; axisID < 3; ++axisID) {
      if (lane_id == axisID) {
        minimumValue = boxMinimum[axisID];
        maximumValue = boxMaximum[axisID];
      }
    }
    
    // Reduce across the entire GPU.
    if (lane_id < 3) {
      atomic_fetch_min_explicit(boundingBox + lane_id,
                                minimumValue, memory_order_relaxed);
      atomic_fetch_max_explicit(boundingBox + 4 + lane_id,
                                maximumValue, memory_order_relaxed);
    }
  }
  
  // Locate the large cell metadata.
  uint largeCellAddress = VoxelAddress::generate(largeVoxelGridWidth, tid);
  
  uchar mark;
  {
    // Locate the mark.
    uint address = VoxelAddress::generate(cellGroupGridWidth, tgid);
    
    // Read the current mark.
    mark = cellGroupMarks[address];
  }
  
  // Return early for vacant voxels.
  if (mark == 0) {
    largeCellOffsets[largeCellAddress] = 0;
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
    largeCellOffsets[largeCellAddress] = 0;
    return;
  }
  
  // Write the large counter metadata.
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
  
  // Write the large cell offset.
  largeCellOffsets[largeCellAddress] = threadVoxelOffset;
  
  // Write the large cell metadata.
  {
    ushort3 cellCoordinates = thread_id;
    cellCoordinates += tgid * 4;
    uchar4 compressedCellCoordinates(uchar3(cellCoordinates), 0);
    
    uint4 threadMetadata(as_type<uint>(compressedCellCoordinates),
                         threadLargeOffset,
                         threadSmallOffset,
                         threadTotalCount & (uint(1 << 14) - 1));
    compactedLargeCellMetadata[threadVoxelOffset] = threadMetadata;
  }
}

kernel void buildLargePart2_0
(
 device uint3 *boundingBox [[buffer(0)]],
 device uchar *cellGroupMarks [[buffer(1)]],
 device vec<uint, 8> *largeCounterMetadata [[buffer(2)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort3 tid [[thread_position_in_grid]])
{
  // A sub-section of the threads converts the bounding box to FP32.
  if (all(tid == 0)) {
    // Read the bounding box.
    uint3 boxMinimum = boundingBox[0];
    uint3 boxMaximum = boundingBox[1];
    boxMaximum = max(boxMinimum, boxMaximum);
    
    // Convert the bounding box to floating point.
    float3 boxMinimumF = float3(boxMinimum);
    float3 boxMaximumF = float3(boxMaximum);
    boxMinimumF = boxMinimumF * 8 - float(worldVolumeInNm / 2);
    boxMaximumF = boxMaximumF * 8 - float(worldVolumeInNm / 2);
    
    // Write the bounding box.
    auto boundingBoxCasted = (device float3*)boundingBox;
    boundingBoxCasted[0] = boxMinimumF;
    boundingBoxCasted[1] = boxMaximumF;
  }
  
  uchar mark;
  {
    // Locate the mark.
    ushort3 cellCoordinates = tgid;
    uint address = VoxelAddress::generate(cellGroupGridWidth,
                                          cellCoordinates);
    
    // Read the mark.
    mark = cellGroupMarks[address];
  }
  
  // Return early if the voxel is empty.
  if (mark == 0) {
    return;
  }
  
  {
    // Locate the large counter metadata.
    ushort3 cellCoordinates = thread_id;
    cellCoordinates += tgid * 4;
    uint address = VoxelAddress::generate(largeVoxelGridWidth,
                                          cellCoordinates);
    
    // Write the large counter metadata.
    vec<uint, 8> resetValue = vec<uint, 8>(0);
    largeCounterMetadata[address] = resetValue;
  }
}

