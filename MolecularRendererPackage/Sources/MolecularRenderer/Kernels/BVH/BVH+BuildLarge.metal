//
//  BVH+BuildLarge.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/26/24.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "../Utilities/VoxelAddress.metal"
using namespace metal;

// Quantize a position relative to the world origin.
inline ushort3 quantize(float3 position, ushort3 world_dims) {
  short3 output = short3(position);
  output = clamp(output, 0, short3(world_dims));
  return ushort3(output);
}

kernel void buildLargePart1_1
(
 // Per-element allocations.
 device float *atomicRadii [[buffer(0)]],
 
 // Per-atom allocations.
 device float4 *originalAtoms [[buffer(1)]],
 device ushort4 *relativeOffsets1 [[buffer(2)]],
 device ushort4 *relativeOffsets2 [[buffer(3)]],
 
 // Per-cell allocations.
 device atomic_uint *largeInputMetadata [[buffer(4)]],
 
 uint tid [[thread_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Materialize the atom.
  float4 atom = originalAtoms[tid];
  {
    uint atomicNumber = uint(atom.w);
    float atomicRadius = atomicRadii[atomicNumber];
    atom.w = atomicRadius;
  }
  
  // Place the atom in the grid of large cells.
  atom.xyz = 4 * (atom.xyz + 64);
  atom.w = 4 * atom.w;
  
  // Generate the bounding box.
  short3 smallVoxelMin = short3(floor(atom.xyz - atom.w));
  short3 smallVoxelMax = short3(ceil(atom.xyz + atom.w));
  smallVoxelMin = max(smallVoxelMin, 0);
  smallVoxelMax = max(smallVoxelMax, 0);
  smallVoxelMin = min(smallVoxelMin, short3(512));
  smallVoxelMax = min(smallVoxelMax, short3(512));
  short3 largeVoxelMin = smallVoxelMin / 8;
  
  // Pre-compute the footprint.
  short3 dividingLine = (largeVoxelMin + 1) * 8;
  dividingLine = min(dividingLine, smallVoxelMax);
  dividingLine = max(dividingLine, smallVoxelMin);
  short3 footprintLow = dividingLine - smallVoxelMin;
  short3 footprintHigh = smallVoxelMax - dividingLine;
  
  // Determine the loop bounds.
  ushort3 loopEnd = select(ushort3(1),
                           ushort3(2),
                           footprintHigh > 0);
  
  // Reorder the loop traversal.
  ushort permutationID;
  if (footprintHigh[0] == 0) {
    permutationID = 0;
  } else if (footprintHigh[1] == 0) {
    permutationID = 1;
  } else {
    permutationID = 2;
  }
  
  if (permutationID == 0) {
    loopEnd = ushort3(loopEnd.y, loopEnd.z, loopEnd.x);
  } else if (permutationID == 1) {
    loopEnd = ushort3(loopEnd.x, loopEnd.z, loopEnd.y);
  } else {
    loopEnd = ushort3(loopEnd.x, loopEnd.y, loopEnd.z);
  }
  
  // Allocate memory for the relative offsets.
  threadgroup ushort cachedRelativeOffsets[8 * 128];
  
  // Iterate over the footprint on the 3D grid.
  for (ushort z = 0; z < loopEnd[2]; ++z) {
    for (ushort y = 0; y < loopEnd[1]; ++y) {
      for (ushort x = 0; x < loopEnd[0]; ++x) {
        ushort3 actualXYZ;
        if (permutationID == 0) {
          actualXYZ = ushort3(z, x, y);
        } else if (permutationID == 1) {
          actualXYZ = ushort3(x, z, y);
        } else {
          actualXYZ = ushort3(x, y, z);
        }
        
        // Determine the number of small voxels within the large voxel.
        short3 footprint =
        select(footprintLow, footprintHigh, bool3(actualXYZ));
        
        // Perform the atomic fetch-add.
        uint offset;
        {
          ushort3 gridDims = ushort3(64);
          ushort3 cubeMin = ushort3(largeVoxelMin) + actualXYZ;
          uint address = VoxelAddress::generate(gridDims, cubeMin);
          address = (address * 8) + (tid % 8);
          
          uint smallReferenceCount =
          footprint[0] * footprint[1] * footprint[2];
          uint word = (smallReferenceCount << 14) + 1;
          
          offset = atomic_fetch_add_explicit(largeInputMetadata + address,
                                             word, memory_order_relaxed);
        }
        
        // Store to the cache.
        {
          ushort address = z * 4 + y * 2 + x;
          address = address * 128 + thread_id;
          cachedRelativeOffsets[address] = ushort(offset);
        }
      }
    }
  }
  
  // Retrieve the cached offsets.
  simdgroup_barrier(mem_flags::mem_threadgroup);
  ushort4 output[2];
#pragma clang loop unroll(full)
  for (ushort i = 0; i < 8; ++i) {
    ushort address = i;
    address = address * 128 + thread_id;
    ushort offset = cachedRelativeOffsets[address];
    output[i / 4][i % 4] = offset;
  }
  
  // Apply the mask.
  constexpr ushort scalarMask = ushort(1 << 14) - 1;
  constexpr uint vectorMask = as_type<uint>(ushort2(scalarMask));
  *((thread uint4*)(output)) &= vectorMask;
  
  // Write to device memory.
  relativeOffsets1[tid] = output[0];
  if (loopEnd[2] == 2) {
    relativeOffsets2[tid] = output[1];
  }
}

kernel void buildLargePart2_0
(
 // Global allocations.
 device uint4 *allocatedMemory [[buffer(0)]],
 device int4 *boundingBoxMin [[buffer(1)]],
 device int4 *boundingBoxMax [[buffer(2)]],
 
 uint tid [[thread_position_in_grid]])
{
  // The first three slots are allocators. We initialize them with the smallest
  // acceptable pointer value.
  // - Large voxel count.
  // - Large reference count.
  // - Small reference count.
  allocatedMemory[0] = uint4(1);
  
  // Next, is the bounding box counter.
  // - Minimum: initial value is +64 nm.
  // - Maximum: initial value is -64 nm.
  boundingBoxMin[0] = int4(64);
  boundingBoxMax[0] = int4(-64);
}

// Inputs:
// - largeInputMetadata (8x duplicate)
//
// Outputs:
// - largeInputMetadata (8x duplicate)
//   - overwritten with large ref. offset
// - largeOutputMetadata
//   - compacted large voxel offset
//   - large reference offset
//   - small reference offset
//   - large refcount (14 bits), small refcount (18 bits)
// - amount of memory allocated
// - compact bounding box for dense DDA traversal
kernel void buildLargePart2_1
(
 // Global allocations.
 device atomic_uint *allocatedMemory [[buffer(0)]],
 device atomic_int *boundingBoxMin [[buffer(1)]],
 device atomic_int *boundingBoxMax [[buffer(2)]],
 
 // Per-cell allocations.
 device vec<uint, 8> *largeInputMetadata [[buffer(3)]],
 device uint4 *largeOutputMetadata [[buffer(4)]],
 
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Locate the cell metadata.
  ushort3 cellCoordinates = tgid * 8 + thread_id;
  ushort3 gridDims = ushort3(64);
  uint cellAddress = VoxelAddress::generate(gridDims, cellCoordinates);
  
  // Reduce across the thread.
  uint threadLargeCount;
  uint threadSmallCount;
  {
    vec<uint, 8> cellMetadata = largeInputMetadata[cellAddress];
    
    uint threadTotalCount = 0;
#pragma clang loop unroll(full)
    for (ushort laneID = 0; laneID < 8; ++laneID) {
      threadTotalCount += cellMetadata[laneID];
    }
    threadLargeCount = threadTotalCount & (uint(1 << 14) - 1);
    threadSmallCount = threadTotalCount >> 14;
  }
  
  // Reduce across the SIMD.
  uint3 simdCounts;
  {
    uint simdVoxelCount = simd_sum(threadLargeCount > 0 ? 1 : 0);
    uint simdLargeCount = simd_sum(threadLargeCount);
    uint simdSmallCount = simd_sum(threadSmallCount);
    simdCounts = uint3(simdVoxelCount,
                       simdLargeCount,
                       simdSmallCount);
  }
  
  // Find the bounding box.
  // - There's probably a more efficient way to do this, if the ALU cost ever
  //   becomes a bottleneck.
  int3 threadBoxMin;
  int3 threadBoxMax;
  if (threadLargeCount > 0) {
    threadBoxMin = int3(cellCoordinates) * 2 - 64;
    threadBoxMax = threadBoxMin + 2;
  } else {
    threadBoxMin = int3(64);
    threadBoxMax = int3(-64);
  }
  int3 simdBoxMin = simd_min(threadBoxMin);
  int3 simdBoxMax = simd_max(threadBoxMax);
  
  // Set up the atomics in threadgroup memory.
  threadgroup int threadgroupCounters[9];
  if (lane_id < 3) {
    threadgroupCounters[lane_id] = 0;
    threadgroupCounters[3 + lane_id] = 64;
    threadgroupCounters[6 + lane_id] = -64;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Reduce across the threadgroup.
  if (lane_id < 3) {
    // Distribute the vector elements across three threads.
    int countValue = 0;
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
    
    auto counts = (threadgroup atomic_int*)(threadgroupCounters + 0);
    auto boxMin = (threadgroup atomic_int*)(threadgroupCounters + 3);
    auto boxMax = (threadgroup atomic_int*)(threadgroupCounters + 6);
    atomic_fetch_add_explicit(counts + lane_id,
                              countValue,
                              memory_order_relaxed);
    atomic_fetch_min_explicit(boxMin + lane_id,
                              boxMinValue,
                              memory_order_relaxed);
    atomic_fetch_max_explicit(boxMax + lane_id,
                              boxMaxValue,
                              memory_order_relaxed);
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Reduce across the entire GPU.
  if (simd_id == 0 && lane_id < 3) {
    int countValue = threadgroupCounters[lane_id];
    int boxMinValue = threadgroupCounters[3 + lane_id];
    int boxMaxValue = threadgroupCounters[6 + lane_id];
    
    atomic_fetch_add_explicit(allocatedMemory + lane_id,
                              countValue,
                              memory_order_relaxed);
    atomic_fetch_min_explicit(boundingBoxMin + lane_id,
                              boxMinValue,
                              memory_order_relaxed);
    atomic_fetch_max_explicit(boundingBoxMax + lane_id,
                              boxMaxValue,
                              memory_order_relaxed);
  }
}
