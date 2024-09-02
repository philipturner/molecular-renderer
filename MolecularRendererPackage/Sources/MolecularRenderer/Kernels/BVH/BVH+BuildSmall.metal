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
 device int3 *boundingBoxMin [[buffer(0)]],
 device int3 *boundingBoxMax [[buffer(1)]],
 device BVHArguments *bvhArgs [[buffer(2)]],
 device uint3 *atomDispatchArguments8x8x8 [[buffer(3)]])
{
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
// Switching to 16-bit references: 1260 μs
kernel void buildSmallPart1_0
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device uint4 *largeCellMetadata [[buffer(1)]],
 device float4 *convertedAtoms [[buffer(2)]],
 device uint *smallCellOffsets [[buffer(3)]],
 device ushort *smallAtomReferences [[buffer(4)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]],
 ushort thread_index [[thread_index_in_threadgroup]])
{
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
  
  // Materialize the base threadgroup address in registers.
  ushort3 localCoordinates = thread_id * ushort3(4, 1, 1);
  ushort baseThreadgroupAddress = VoxelAddress::generate(8, localCoordinates);
  
  // Initialize the small-cell counters.
  threadgroup uint threadgroupCounters[512];
  for (ushort i = thread_index; i < 512; i += 128) {
    uint resetValue = uint(0);
    threadgroupCounters[i] = resetValue;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device);
  
  // MARK: - buildSmallPart1_1
  {
    // Iterate over the atoms.
    ushort largeReferenceCount = metadata[3] & (uint(1 << 14) - 1);
    for (ushort smallAtomID = thread_index;
         smallAtomID < largeReferenceCount;
         smallAtomID += 128)
    {
      // Materialize the atom.
      uint largeReferenceOffset = metadata[1];
      uint largeReferenceID = largeReferenceOffset + 1 + smallAtomID;
      float4 atom = convertedAtoms[largeReferenceID];
      
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
      
      // Iterate over the footprint on the 3D grid.
      for (ushort z = loopStart[2]; z < loopEnd[2]; ++z) {
        for (ushort y = loopStart[1]; y < loopEnd[1]; ++y) {
          for (ushort x = loopStart[0]; x < loopEnd[0]; ++x) {
            ushort3 actualXYZ = ushort3(x, y, z);
            
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
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device);
  
  // Read the counter metadata.
  uint4 conservativeCounts;
#pragma clang loop unroll(full)
  for (ushort laneID = 0; laneID < 4; ++laneID) {
    ushort localAddress = baseThreadgroupAddress + laneID;
    uint atomCount = threadgroupCounters[localAddress];
    
    // If there might be an atom in this voxel, insert a null terminator.
    if (atomCount > 0) {
      atomCount += 1;
    }
    conservativeCounts[laneID] = atomCount;
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device);
  
  // MARK: - buildSmallPart2_1
  
  uint4 counterOffsets;
  {
    // Reduce across the thread.
    uint threadCount = 0;
#pragma clang loop unroll(full)
    for (ushort laneID = 0; laneID < 4; ++laneID) {
      uint counterOffset = threadCount;
      threadCount += conservativeCounts[laneID];
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
    uint groupOffset = metadata[2];
    threadOffset += groupOffset;
    threadOffset += simdOffset;
    counterOffsets += threadOffset;
    
    // Write the counter metadata.
#pragma clang loop unroll(full)
    for (ushort laneID = 0; laneID < 4; ++laneID) {
      uint offset = counterOffsets[laneID];
      ushort cellAddress = baseThreadgroupAddress + laneID;
      threadgroupCounters[cellAddress] = offset;
    }
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device);
  
  // MARK: - buildSmallPart2_2
  {
    // Iterate over the atoms.
    ushort largeReferenceCount = metadata[3] & (uint(1 << 14) - 1);
    for (ushort smallAtomID = thread_index;
         smallAtomID < largeReferenceCount;
         smallAtomID += 128)
    {
      // Materialize the atom.
      uint largeReferenceOffset = metadata[1];
      uint largeReferenceID = largeReferenceOffset + 1 + smallAtomID;
      float4 atom = convertedAtoms[largeReferenceID];
      
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
            smallAtomReferences[offset] = 1 + smallAtomID;
          }
        }
      }
    }
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device);
  
  {
    ushort3 cellCoordinates = thread_id * ushort3(4, 1, 1);
    cellCoordinates += tgid * 8;
    ushort3 gridDims = bvhArgs->smallVoxelCount;
    uint baseDeviceAddress = VoxelAddress::generate(gridDims, cellCoordinates);
    
#pragma clang loop unroll(full)
    for (ushort laneID = 0; laneID < 4; ++laneID) {
      ushort localAddress = baseThreadgroupAddress + laneID;
      uint allocationStart = counterOffsets[laneID];
      uint allocationEnd = threadgroupCounters[localAddress];
      
      // Revise the reference count, with a tighter estimate.
      uint atomCount = allocationEnd - allocationStart;
      
      // Write the null terminator.
      if (atomCount > 0) {
        smallAtomReferences[allocationEnd] = 0;
      }
      
      // Flag this voxel as empty.
      if (atomCount == 0) {
        allocationStart = 0;
      }
      
      // Write the cell metadata.
      uint globalAddress = baseDeviceAddress + laneID;
      smallCellOffsets[globalAddress] = allocationStart;
    }
  }
}
