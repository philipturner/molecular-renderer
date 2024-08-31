//
//  BVH+BuildSmall+Atoms.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "../Utilities/VoxelAddress.metal"
using namespace metal;

inline ushort3 clamp(float3 position, ushort3 gridDims) {
  short3 output = short3(position);
  output = clamp(output, 0, short3(gridDims));
  return ushort3(output);
}

// Test whether an atom overlaps a 1x1x1 cube.
inline bool cubeSphereIntersection(ushort3 cube_min, float4 atom)
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

kernel void buildSmallPart0_0
(
 device uint3 *allocatedMemory [[buffer(0)]],
 device int3 *boundingBoxMin [[buffer(1)]],
 device int3 *boundingBoxMax [[buffer(2)]],
 device BVHArguments *bvhArgs [[buffer(3)]],
 device uint3 *atomDispatchArguments8x8x8 [[buffer(4)]])
{
  // Initialize with the smallest acceptable pointer value.
  uint smallestPointer = uint(1);
  *allocatedMemory = smallestPointer;
  
  // Read the bounding box.
  int3 minimum = *boundingBoxMin;
  int3 maximum = *boundingBoxMax;
  
  // Clamp the bounding box to the world volume.
  minimum = max(minimum, -64);
  maximum = min(maximum, 64);
  maximum = max(minimum, maximum);
  bvhArgs->worldMinimum = float3(minimum);
  bvhArgs->worldMaximum = float3(maximum);
  
  // Compute the grid dimensions.
  ushort3 largeVoxelCount = ushort3((maximum - minimum) / 2);
  bvhArgs->largeVoxelCount = largeVoxelCount;
  bvhArgs->smallVoxelCount = largeVoxelCount * 8;
  
  // Set the atom dispatch arguments.
  *atomDispatchArguments8x8x8 = uint3(largeVoxelCount);
}

// MARK: - Kernels

// Before:                    380 microseconds
// After reducing divergence: 350 microseconds
// Duplicating large atoms:   950 microseconds
// Increasing divergence:     960 milliseconds
//
// Consistently ~600-650 microseconds now, for an unknown reason.
// Saving 32 relative offsets:  750 microseconds
// Saving 16 relative offsets:  770 microseconds
// Saving 16, recomputing rest: 720 microseconds
// Saving 8, recomputing rest:  650 microseconds
//
// Dispatch over 128 threads: 750 microseconds
// Dispatch over 256 threads: 710 microseconds
// Threadgroup atomics:       440 microseconds
kernel void buildSmallPart1_1
(
 device atomic_uint *allocatedMemory [[buffer(0)]],
 constant BVHArguments *bvhArgs [[buffer(1)]],
 device uint4 *largeCellMetadata [[buffer(2)]],
 device uint *largeAtomReferences [[buffer(3)]],
 device float4 *convertedAtoms [[buffer(4)]],
 device uint *smallCounterMetadata [[buffer(5)]],
 device uint *smallCellMetadata [[buffer(6)]],
 device uint *smallAtomReferences [[buffer(7)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]],
 ushort thread_index [[thread_index_in_threadgroup]])
{
  // MARK: - buildSmallPart1_1
  {
    // Initialize the small-cell counters.
    threadgroup uint threadgroupCounters[512];
    for (ushort i = thread_index; i < 512; i += 128) {
      threadgroupCounters[i] = 0;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Materialize the lower corner in registers.
    float3 lowerCorner = bvhArgs->worldMinimum;
    lowerCorner += float3(tgid) * 2;
    
    // Read the large cell metadata.
    uint4 metadata;
    {
      ushort3 cellCoordinates = ushort3(lowerCorner + 64);
      cellCoordinates /= 2;
      ushort3 gridDims = ushort3(64);
      uint cellAddress = VoxelAddress::generate(gridDims, cellCoordinates);
      metadata = largeCellMetadata[cellAddress];
    }
    
    // Iterate over the atoms.
    ushort largeReferenceCount = metadata[3] & (uint(1 << 14) - 1);
    for (ushort smallAtomID = thread_index;
         smallAtomID < largeReferenceCount;
         smallAtomID += 128)
    {
      // Materialize the atom.
      uint largeReferenceOffset = metadata[1];
      uint largeReferenceID = largeReferenceOffset + smallAtomID;
      uint largeAtomID = largeAtomReferences[largeReferenceID];
      float4 atom = convertedAtoms[largeAtomID];
      
      // Generate the bounding box.
      ushort3 loopStart;
      ushort3 loopEnd;
      {
        float3 smallVoxelMin = atom.xyz - atom.w;
        float3 smallVoxelMax = atom.xyz + atom.w;
        smallVoxelMin = max(smallVoxelMin, lowerCorner);
        smallVoxelMax = min(smallVoxelMax, lowerCorner + 2);
        smallVoxelMin = 4 * (smallVoxelMin - bvhArgs->worldMinimum);
        smallVoxelMax = 4 * (smallVoxelMax - bvhArgs->worldMinimum);
        smallVoxelMin = floor(smallVoxelMin);
        smallVoxelMax = ceil(smallVoxelMax);
        
        ushort3 gridDims = bvhArgs->smallVoxelCount;
        loopStart = clamp(smallVoxelMin, gridDims);
        loopEnd = clamp(smallVoxelMax, gridDims);
      }
      
      // Place the atom in the grid of small cells.
      atom.xyz = 4 * (atom.xyz - bvhArgs->worldMinimum);
      atom.w = 4 * atom.w;
      
      // Iterate over the footprint on the 3D grid.
      for (ushort z = loopStart[2]; z < loopEnd[2]; ++z) {
        for (ushort y = loopStart[1]; y < loopEnd[1]; ++y) {
          for (ushort x = loopStart[0]; x < loopEnd[0]; ++x) {
            ushort3 actualXYZ = ushort3(x, y, z);
            
            // Narrow down the cells with a cube-sphere intersection test.
            //
            // TODO: Eliminate the first test, once it is possible to do so. We
            // will need to re-compute the small-cell metadata with the revised
            // atom count.
            bool intersected = cubeSphereIntersection(actualXYZ, atom);
            if (!intersected) {
              continue;
            }
            
            // Generate the address.
            ushort3 gridDims = ushort3(8);
            ushort3 cellCoordinates = actualXYZ - tgid * 8;
            ushort address = VoxelAddress::generate(gridDims, cellCoordinates);
            
            // Perform the atomic fetch-add.
            auto castedCounters =
            (threadgroup atomic_uint*)threadgroupCounters;
            atomic_fetch_add_explicit(castedCounters + address,
                                      1, memory_order_relaxed);
          }
        }
      }
    }
    
    // Write the small-cell counters.
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (ushort smallCellID = thread_index;
         smallCellID < 512;
         smallCellID += 128)
    {
      ushort3 localCoordinates(smallCellID % 8,
                               (smallCellID % 64) / 8,
                               smallCellID / 64);
      ushort3 localGridDims = 8;
      ushort localCellAddress = VoxelAddress::generate(localGridDims,
                                                       localCoordinates);
      
      ushort3 globalCoordinates = tgid * 8 + localCoordinates;
      ushort3 globalGridDims = bvhArgs->smallVoxelCount;
      uint globalCellAddress = VoxelAddress::generate(globalGridDims,
                                                      globalCoordinates);
      
      uint offset = threadgroupCounters[localCellAddress];
      smallCounterMetadata[globalCellAddress] = offset;
    }
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device);
  
  // MARK: - buildSmallPart2_1
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
}

// Before:                    1.1 milliseconds
// After reducing divergence: 1.1 milliseconds
// Duplicating large atoms:   2.0 milliseconds
// Increasing divergence:     1.9 milliseconds
//
// Consistently ~1.2-1.3 milliseconds now, for an unknown reason.
// Saving 32 relative offsets:  670 microseconds
// Saving 16 relative offsets:  620 microseconds
// Saving 16, recomputing rest: 710 microseconds
// Saving 8, recomputing rest:  610 microseconds
//
// Dispatch over 128 threads: 1.8 milliseconds
// Dispatch over 256 threads: 1.6 milliseconds
// Threadgroup atomics:       1.2 milliseconds
kernel void buildSmallPart2_2
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device uint4 *largeCellMetadata [[buffer(1)]],
 device uint *largeAtomReferences [[buffer(2)]],
 device float4 *convertedAtoms [[buffer(3)]],
 device uint *smallCounterMetadata [[buffer(4)]],
 device uint *smallAtomReferences [[buffer(5)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]],
 ushort thread_index [[thread_index_in_threadgroup]])
{
  // Read the small-cell counters.
  threadgroup uint threadgroupCounters[512];
  for (ushort smallCellID = thread_index;
       smallCellID < 512;
       smallCellID += 128)
  {
    ushort3 localCoordinates(smallCellID % 8,
                            (smallCellID % 64) / 8,
                            smallCellID / 64);
    ushort3 localGridDims = 8;
    ushort localCellAddress = VoxelAddress::generate(localGridDims,
                                                     localCoordinates);
    
    ushort3 globalCoordinates = tgid * 8 + localCoordinates;
    ushort3 globalGridDims = bvhArgs->smallVoxelCount;
    uint globalCellAddress = VoxelAddress::generate(globalGridDims,
                                                    globalCoordinates);
    
    uint offset = smallCounterMetadata[globalCellAddress];
    threadgroupCounters[localCellAddress] = offset;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Materialize the lower corner in registers.
  float3 lowerCorner = bvhArgs->worldMinimum;
  lowerCorner += float3(tgid) * 2;
  
  // Read the large cell metadata.
  uint4 metadata;
  {
    ushort3 cellCoordinates = ushort3(lowerCorner + 64);
    cellCoordinates /= 2;
    ushort3 gridDims = ushort3(64);
    uint cellAddress = VoxelAddress::generate(gridDims, cellCoordinates);
    metadata = largeCellMetadata[cellAddress];
  }
  
  // Iterate over the atoms.
  ushort largeReferenceCount = metadata[3] & (uint(1 << 14) - 1);
  for (ushort smallAtomID = thread_index;
       smallAtomID < largeReferenceCount;
       smallAtomID += 128)
  {
    // Materialize the atom.
    uint largeReferenceOffset = metadata[1];
    uint largeReferenceID = largeReferenceOffset + smallAtomID;
    uint largeAtomID = largeAtomReferences[largeReferenceID];
    float4 atom = convertedAtoms[largeAtomID];
    
    // Generate the bounding box.
    ushort3 loopStart;
    ushort3 loopEnd;
    {
      float3 smallVoxelMin = atom.xyz - atom.w;
      float3 smallVoxelMax = atom.xyz + atom.w;
      smallVoxelMin = max(smallVoxelMin, lowerCorner);
      smallVoxelMax = min(smallVoxelMax, lowerCorner + 2);
      smallVoxelMin = 4 * (smallVoxelMin - bvhArgs->worldMinimum);
      smallVoxelMax = 4 * (smallVoxelMax - bvhArgs->worldMinimum);
      smallVoxelMin = floor(smallVoxelMin);
      smallVoxelMax = ceil(smallVoxelMax);
      
      ushort3 gridDims = bvhArgs->smallVoxelCount;
      loopStart = clamp(smallVoxelMin, gridDims);
      loopEnd = clamp(smallVoxelMax, gridDims);
    }
    
    // Place the atom in the grid of small cells.
    atom.xyz = 4 * (atom.xyz - bvhArgs->worldMinimum);
    atom.w = 4 * atom.w;
    
    // Iterate over the footprint on the 3D grid.
    for (ushort z = loopStart[2]; z < loopEnd[2]; ++z) {
      for (ushort y = loopStart[1]; y < loopEnd[1]; ++y) {
        for (ushort x = loopStart[0]; x < loopEnd[0]; ++x) {
          ushort3 actualXYZ = ushort3(x, y, z);
          
          // Narrow down the cells with a cube-sphere intersection test.
          bool intersected = cubeSphereIntersection(actualXYZ, atom);
          if (!intersected) {
            continue;
          }
          
          // Generate the address.
          ushort3 gridDims = ushort3(8);
          ushort3 cellCoordinates = actualXYZ - tgid * 8;
          ushort address = VoxelAddress::generate(gridDims, cellCoordinates);
          
          // Perform the atomic fetch-add.
          auto castedCounters =
          (threadgroup atomic_uint*)threadgroupCounters;
          uint offset =
          atomic_fetch_add_explicit(castedCounters + address,
                                    1, memory_order_relaxed);
          
          // Write the reference to the list.
          smallAtomReferences[offset] = largeAtomID;
        }
      }
    }
  }
}
