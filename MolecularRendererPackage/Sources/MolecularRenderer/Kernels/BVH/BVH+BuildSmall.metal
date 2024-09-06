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
 device uint3 *atomDispatchArguments8x8x8 [[buffer(1)]])
{
  // Set the atom dispatch arguments.
  uint compactedThreadgroupCount = allocatedMemory[0] - 1;
  uint3 threadgroupGridSize = uint3(compactedThreadgroupCount, 1, 1);
  *atomDispatchArguments8x8x8 = threadgroupGridSize;
}

kernel void buildSmallPart1_0
(
 device uint4 *compactedLargeCellMetadata [[buffer(0)]],
 device half4 *convertedAtoms [[buffer(1)]],
 device ushort2 *compactedSmallCellMetadata [[buffer(2)]],
 device ushort *smallAtomReferences [[buffer(3)]],
 uint tgid [[threadgroup_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Read the large cell metadata.
  uint4 largeMetadata = compactedLargeCellMetadata[1 + tgid];
  
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
          
          // Generate the address.
          half address = VoxelAddress::generate<half, half>(8, xyz);
          
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
    
    // Generate the bounding box.
    half3 smallVoxelMin = atom.xyz - atom.w;
    half3 smallVoxelMax = atom.xyz + atom.w;
    smallVoxelMin = max(smallVoxelMin, 0);
    smallVoxelMax = min(smallVoxelMax, 8);
    smallVoxelMin = floor(smallVoxelMin);
    smallVoxelMax = ceil(smallVoxelMax);
    
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
          if (intersected && all(xyz < smallVoxelMax)) {
            // Generate the address.
            half address = VoxelAddress::generate<half, half>(8, xyz);
            
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
    uint compactedGlobalAddress = (1 + tgid) * 512 + localAddress;
    compactedSmallCellMetadata[compactedGlobalAddress] = output;
  }
}
