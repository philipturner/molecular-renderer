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
 device vec<uint, 8> *largeCounterMetadata [[buffer(0)]],
 uint tid [[thread_position_in_grid]])
{
  largeCounterMetadata[tid] = vec<uint, 8>(0);
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
  allocatedMemory[0] = uint3(1);
  
  // Next, is the bounding box counter.
  // - Minimum: initial value is +64 nm.
  // - Maximum: initial value is -64 nm.
  boundingBoxMin[0] = int3(64);
  boundingBoxMax[0] = int3(-64);
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
//   - large refcount (14 bits), small refcount (18 bits)
// - amount of memory allocated
// - compact bounding box for dense DDA traversal
kernel void buildLargePart2_1
(
 // Global counters.
 device atomic_uint *allocatedMemory [[buffer(0)]],
 device atomic_int *boundingBoxMin [[buffer(1)]],
 device atomic_int *boundingBoxMax [[buffer(2)]],
 
 // Per-cell allocations.
 device vec<uint, 8> *largeCounterMetadata [[buffer(3)]],
 device uint4 *largeCellMetadata [[buffer(4)]],
 
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Read the counts.
  ushort3 cellCoordinates = thread_id;
  cellCoordinates += tgid * ushort3(4, 4, 4);
  ushort3 gridDims = ushort3(64);
  uint cellAddress = VoxelAddress::generate(gridDims, cellCoordinates);
  vec<uint, 8> counterCounts = largeCounterMetadata[cellAddress];
  
  // Reduce the counts across the thread.
  vec<ushort, 8> counterOffsets;
  uint threadTotalCount = 0;
#pragma clang loop unroll(full)
  for (ushort laneID = 0; laneID < 8; ++laneID) {
    ushort counterOffset = ushort(threadTotalCount) & (ushort(1 << 14) - 1);
    threadTotalCount += counterCounts[laneID];
    counterOffsets[laneID] = counterOffset;
  }
  
  // Reduce the counts across the SIMD.
  uint3 threadOffsets;
  uint3 simdCounts;
  {
    uint threadVoxelCount = (threadTotalCount > 0) ? 1 : 0;
    uint threadLargeCount = threadTotalCount & (uint(1 << 14) - 1);
    uint threadSmallCount = threadTotalCount >> 14;
    uint3 threadCounts(threadVoxelCount,
                       threadLargeCount,
                       threadSmallCount);
    
    threadOffsets = simd_prefix_exclusive_sum(threadCounts);
    simdCounts = simd_broadcast(threadOffsets + threadCounts, 31);
  }
  
  // If the entire SIMD is empty, return here.
  if (simdCounts[0] == 0) {
    largeCellMetadata[cellAddress] = uint4(0);
    return;
  }
  
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
  
  // Store the thread metadata.
  {
    uint4 threadMetadata(threadVoxelOffset,
                         threadLargeOffset,
                         threadSmallOffset,
                         threadTotalCount);
    largeCellMetadata[cellAddress] = threadMetadata;
  }
  
  // Add the thread offset to the per-counter offset.
  {
    vec<uint, 8> counterOffsets32 = vec<uint, 8>(counterOffsets);
    counterOffsets32 += threadLargeOffset;
    largeCounterMetadata[cellAddress] = counterOffsets32;
  }
}
