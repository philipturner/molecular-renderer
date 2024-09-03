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

inline ushort pickPermutation(half3 footprint) {
  ushort output;
  if (footprint[0] < footprint[1] && footprint[0] < footprint[2]) {
    output = 0;
  } else if (footprint[0] < footprint[1]) {
    output = 1;
  } else {
    output = 2;
  }
  return output;
}

inline half3 reorderForward(half3 loopBound, ushort permutationID) {
  half3 output;
  if (permutationID == 0) {
    output = half3(loopBound[1], loopBound[2], loopBound[0]);
  } else if (permutationID == 1) {
    output = half3(loopBound[0], loopBound[2], loopBound[1]);
  } else {
    output = half3(loopBound[0], loopBound[1], loopBound[2]);
  }
  return output;
}

inline ushort3 reorderBackward(ushort3 loopBound, ushort permutationID) {
  ushort3 output;
  if (permutationID == 0) {
    output = ushort3(loopBound[2], loopBound[0], loopBound[1]);
  } else if (permutationID == 1) {
    output = ushort3(loopBound[0], loopBound[2], loopBound[1]);
  } else {
    output = ushort3(loopBound[0], loopBound[1], loopBound[2]);
  }
  return output;
}

// Test whether an atom overlaps a 1x1x1 cube.
inline bool cubeSphereIntersection(half3 cube_min, half4 atom)
{
  half3 c1 = cube_min;
  half3 c2 = c1 + 1;
  half3 delta_c1 = atom.xyz - c1;
  half3 delta_c2 = atom.xyz - c2;
  
  half dist_squared = atom.w * atom.w;
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
 device uint *allocatedMemory [[buffer(0)]],
 device BVHArguments *bvhArgs [[buffer(1)]],
 device uint3 *atomDispatchArguments8x8x8 [[buffer(2)]])
{
  // Set the BVH arguments.
  bvhArgs->worldMinimum = -64;
  bvhArgs->worldMaximum = 64;
  bvhArgs->largeVoxelCount = 64;
  bvhArgs->smallVoxelCount = 512;
  
  // Set the atom dispatch arguments.
  uint compactedThreadgroupCount = allocatedMemory[0] - 1;
  uint3 threadgroupGridSize = uint3(compactedThreadgroupCount, 1, 1);
  *atomDispatchArguments8x8x8 = threadgroupGridSize;
}

// Before:                    380 μs + 1100 μs
// After reducing divergence: 350 μs + 1100 μs
// Duplicating large atoms:   950 μs + 2000 μs
// Increasing divergence:     960 μs + 1900 μs
//
// Consistently 600-650 μs + 1200-1300 μs now, for an unknown reason.
// Saving 32 relative offsets:  750 μs + 670 μs
// Saving 16 relative offsets:  770 μs + 620 μs
// Saving 16, recomputing rest: 720 μs + 710 μs
// Saving 8, recomputing rest:  650 μs + 610 μs
//
// Dispatch over 128 threads: 750 μs + 1800 μs
// Dispatch over 256 threads: 710 μs + 1600 μs
// Threadgroup atomics:       440 μs + 1200 μs
//
// Fusion into a single kernel:    1290 μs
// Removing the counters buffer:   1390 μs
// Switching to 16-bit references: 1260 μs | 42.4% divergence
// Reordering the second loop:     1210 μs | 41.6% divergence
// Switching to 16-bit atoms:      1020 μs |
kernel void buildSmallPart1_0
(
 device uint4 *largeCellMetadata [[buffer(1)]],
 device uchar3 *compactedLargeCellIDs [[buffer(2)]],
 device half4 *convertedAtoms [[buffer(3)]],
 device ushort2 *compactedSmallCellMetadata [[buffer(4)]],
 device ushort *smallAtomReferences [[buffer(5)]],
 uint tgid [[threadgroup_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Materialize the lower corner in registers.
  uchar3 cellCoordinates = compactedLargeCellIDs[1 + tgid];
  float3 lowerCorner = float3(cellCoordinates) * 2 - 64;
  
  // Read the large cell metadata.
  uint4 largeMetadata;
  {
    ushort3 cellCoordinates = ushort3(lowerCorner + 64);
    cellCoordinates /= 2;
    uint cellAddress = VoxelAddress::generate(64, cellCoordinates);
    largeMetadata = largeCellMetadata[cellAddress];
  }
  if (largeMetadata[0] == 0) {
    return;
  }
  
  // Initialize the small-cell counters.
  threadgroup uint threadgroupCounters[512];
  for (ushort i = thread_id; i < 512; i += 128) {
    uint resetValue = uint(0);
    threadgroupCounters[i] = resetValue;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Iterate over the atoms.
  for (ushort smallAtomID = thread_id;
       smallAtomID < largeMetadata[3];
       smallAtomID += 128)
  {
    // Materialize the atom.
    uint largeReferenceOffset = largeMetadata[1];
    uint largeReferenceID = largeReferenceOffset + smallAtomID;
    half4 atom = convertedAtoms[largeReferenceID];
    atom *= 4;
    
    // Generate the bounding box.
    half3 smallVoxelMin = atom.xyz - atom.w - 0.001;
    half3 smallVoxelMax = atom.xyz + atom.w + 0.001;
    smallVoxelMin = max(smallVoxelMin, 0);
    smallVoxelMax = min(smallVoxelMax, 8);
    smallVoxelMin = floor(smallVoxelMin);
    smallVoxelMax = ceil(smallVoxelMax);
    
    // Iterate over the footprint on the 3D grid.
    for (half z = smallVoxelMin[2]; z < smallVoxelMax[2]; ++z) {
      for (half y = smallVoxelMin[1]; y < smallVoxelMax[1]; ++y) {
        for (half x = smallVoxelMin[0]; x < smallVoxelMax[0]; ++x) {
          half3 xyz = half3(x, y, z);
          
          // Generate the address.
          constexpr half3 addressStride(1, 8, 64);
          half address = dot(xyz, addressStride);
          
          // Perform the atomic fetch-add.
          auto castedCounters =
          (threadgroup atomic_uint*)threadgroupCounters;
          atomic_fetch_add_explicit(castedCounters + ushort(address),
                                    1, memory_order_relaxed);
        }
      }
    }
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  
  
  uint4 counterOffsets;
  {
    // Read the counter metadata.
    uint4 counts = ((threadgroup uint4*)threadgroupCounters)[thread_id];
    
    // Reduce across the thread.
    uint threadCount = 0;
#pragma clang loop unroll(full)
    for (ushort laneID = 0; laneID < 4; ++laneID) {
      uint counterOffset = threadCount;
      threadCount += counts[laneID];
      counterOffsets[laneID] = counterOffset;
    }
    
    // Reduce across the SIMD.
    uint threadOffset = simd_prefix_exclusive_sum(threadCount);
    uint simdCount = simd_broadcast(threadOffset + threadCount, 31);
    
    // Reduce across the entire group.
    threadgroup uint simdCounts[4];
    simdCounts[simd_id] = simdCount;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    uint otherSIMDCount = simdCounts[lane_id % 4];
    uint otherSIMDOffset = simd_prefix_exclusive_sum(otherSIMDCount);
    uint simdOffset = simd_broadcast(otherSIMDOffset, simd_id);
    
    // Sum the following, to create the compacted small voxel offset.
    // - Threadgroup offset (large voxel offset)
    // - SIMD offset
    // - Thread offset
    // - Cell offset (small voxel offset)
    uint groupOffset = largeMetadata[2];
    threadOffset += groupOffset;
    threadOffset += simdOffset;
    counterOffsets += threadOffset;
    
    // Write the counter metadata.
    // - The barrier for 'simdCounts' also serves as the barrier between
    //   reading 'conservativeCounts' and writing 'offset'.
    ((threadgroup uint4*)threadgroupCounters)[thread_id] = counterOffsets;
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Iterate over the atoms.
  for (ushort smallAtomID = thread_id;
       smallAtomID < largeMetadata[3];
       smallAtomID += 128)
  {
    // Materialize the atom.
    uint largeReferenceOffset = largeMetadata[1];
    uint largeReferenceID = largeReferenceOffset + smallAtomID;
    half4 atom = convertedAtoms[largeReferenceID];
    atom *= 4;
    
    /*
    
    // Generate the bounding box.
    half3 smallVoxelMin = atom.xyz - atom.w;
    smallVoxelMin = max(smallVoxelMin, 0);
    smallVoxelMin = floor(smallVoxelMin);
    
    // Iterate over the footprint on the 3D grid.
#pragma clang loop unroll(disable)
    for (half z = 0; z < 3; ++z) {
#pragma clang loop unroll(full)
      for (half y = 0; y < 3; ++y) {
#pragma clang loop unroll(full)
        for (half x = 0; x < 3; ++x) {
          half3 xyz = smallVoxelMin + half3(x, y, z);
          
          // Narrow down the cells with a cube-sphere intersection test.
          bool intersected = cubeSphereIntersection(xyz, atom);
          if (intersected && all(xyz < 8)) {
            // Generate the address.
            constexpr half3 addressStride(1, 8, 64);
            half address = dot(xyz, addressStride);
            
            // Perform the atomic fetch-add.
            auto castedCounters =
            (threadgroup atomic_uint*)threadgroupCounters;
            uint offset =
            atomic_fetch_add_explicit(castedCounters + ushort(address),
                                      1, memory_order_relaxed);
            
            // Write the reference to the list.
            smallAtomReferences[offset] = smallAtomID;
          }
        }
      }
    }
     */
    
    // Generate the bounding box.
    half3 smallVoxelMin = atom.xyz - atom.w;
    half3 smallVoxelMax = atom.xyz + atom.w;
    smallVoxelMin = max(smallVoxelMin, 0);
    smallVoxelMax = min(smallVoxelMax, 8);
    smallVoxelMin = floor(smallVoxelMin);
    smallVoxelMax = ceil(smallVoxelMax);
    
    // Iterate over the footprint on the 3D grid.
    for (half z = smallVoxelMin[2]; z < smallVoxelMax[2]; ++z) {
      for (half y = smallVoxelMin[1]; y < smallVoxelMax[1]; ++y) {
        for (half x = smallVoxelMin[0]; x < smallVoxelMax[0]; ++x) {
          half3 xyz = half3(x, y, z);
          
          // Narrow down the cells with a cube-sphere intersection test.
          bool intersected = cubeSphereIntersection(xyz, atom);
          if (intersected && all(xyz < 8)) {
            // Generate the address.
            constexpr half3 addressStride(1, 8, 64);
            half address = dot(xyz, addressStride);
            
            // Perform the atomic fetch-add.
            auto castedCounters =
            (threadgroup atomic_uint*)threadgroupCounters;
            uint offset =
            atomic_fetch_add_explicit(castedCounters + ushort(address),
                                      1, memory_order_relaxed);
            
            // Write the reference to the list.
            smallAtomReferences[offset] = smallAtomID;
          }
        }
      }
    }
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
#pragma clang loop unroll(full)
  for (ushort laneID = 0; laneID < 4; ++laneID) {
    ushort localAddress = thread_id * 4 + laneID;
    uint allocationStart = counterOffsets[laneID];
    uint allocationEnd = threadgroupCounters[localAddress];
    
    ushort2 output;
    if (allocationStart < allocationEnd) {
      // Make the offset relative to the large voxel's base address.
      output[0] = allocationStart - largeMetadata[2];
      output[1] = allocationEnd - allocationStart;
    } else {
      // Flag this voxel as empty.
      output = as_type<ushort2>(uint(0));
    }
    
    // Write the compacted cell metadata.
    uint compactedGlobalAddress = largeMetadata[0] * 512 + localAddress;
    compactedSmallCellMetadata[compactedGlobalAddress] = output;
  }
}
