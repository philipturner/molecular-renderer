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

inline ushort pickPermutation(ushort3 footprint) {
  ushort output;
  if (footprint[0] < footprint[1] && footprint[0] < footprint[2]) {
    output = 0;
  } else if (footprint[1] < footprint[2]) {
    output = 1;
  } else {
    output = 2;
  }
  return output;
}

inline ushort3 reorderForward(ushort3 loopBound, ushort permutationID) {
  ushort3 output;
  if (permutationID == 0) {
    output = ushort3(loopBound[1], loopBound[2], loopBound[0]);
  } else if (permutationID == 1) {
    output = ushort3(loopBound[0], loopBound[2], loopBound[1]);
  } else {
    output = ushort3(loopBound[0], loopBound[1], loopBound[2]);
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

inline ushort3 clamp(short3 position, ushort3 world_dims) {
  short3 output = position;
  output = clamp(output, 0, short3(world_dims));
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

// MARK: - Kernels

constexpr constant ushort savedRefs = 8;

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
kernel void buildSmallPart1_1
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device float4 *convertedAtoms [[buffer(1)]],
 device vec<uchar, savedRefs> *relativeOffsets [[buffer(2)]],
 device atomic_uint *smallCounterMetadata [[buffer(3)]],
 uint tid [[thread_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Allocate memory for the relative offsets.
  threadgroup uchar cachedRelativeOffsets[savedRefs * 128];
  
  // Materialize the atom.
  float4 atom = convertedAtoms[tid];
  
  // Place the atom in the grid of small cells.
  atom.xyz = 4 * (atom.xyz - bvhArgs->worldMinimum);
  atom.w = 4 * atom.w;
  
  // Generate the bounding box.
  ushort3 loopStart;
  ushort3 loopEnd;
  {
    short3 smallVoxelMin = short3(floor(atom.xyz - atom.w));
    short3 smallVoxelMax = short3(ceil(atom.xyz + atom.w));
    
    ushort3 gridDims = bvhArgs->smallVoxelCount;
    loopStart = clamp(smallVoxelMin, gridDims);
    loopEnd = clamp(smallVoxelMax, gridDims);
  }
  
  // Reorder the loop traversal.
  ushort permutationID = pickPermutation(loopEnd - loopStart);
  loopStart = reorderForward(loopStart, permutationID);
  loopEnd = reorderForward(loopEnd, permutationID);
  
  // Iterate over the footprint on the 3D grid.
  simdgroup_barrier(mem_flags::mem_threadgroup);
  ushort offsetCursor = 0;
  for (ushort z = loopStart[2]; z < loopEnd[2]; ++z) {
    for (ushort y = loopStart[1]; y < loopEnd[1]; ++y) {
      for (ushort x = loopStart[0]; x < loopEnd[0]; ++x) {
        ushort3 actualXYZ = ushort3(x, y, z);
        actualXYZ = reorderBackward(actualXYZ, permutationID);
        
        // Narrow down the cells with a cube-sphere intersection test.
        bool intersected = cubeSphereIntersection(actualXYZ, atom);
        if (!intersected) {
          continue;
        }
        
        // Generate the address.
        ushort3 gridDims = bvhArgs->smallVoxelCount;
        uint address = VoxelAddress::generate(gridDims, actualXYZ);
        if (offsetCursor >= savedRefs) {
          address += 512 * 512 * 256;
        }
        
        // Perform the atomic fetch-add.
        uint offset;
        offset = atomic_fetch_add_explicit(smallCounterMetadata + address,
                                           1, memory_order_relaxed);
        
        // Store to the cache.
        if (offsetCursor < savedRefs) {
          ushort address = offsetCursor;
          address = address * 128 + thread_id;
          offsetCursor += 1;
          
          cachedRelativeOffsets[address] = uchar(offset);
        }
      }
    }
  }
  
  {
    // Retrieve the cached offsets.
    simdgroup_barrier(mem_flags::mem_threadgroup);
    vec<uchar, savedRefs> output;
#pragma clang loop unroll(full)
    for (ushort i = 0; i < savedRefs; ++i) {
      ushort address = i;
      address = address * 128 + thread_id;
      uchar offset = cachedRelativeOffsets[address];
      output[i] = offset;
    }
    
    // Write to device memory.
    relativeOffsets[tid] = output;
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
kernel void buildSmallPart2_2
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device float4 *convertedAtoms [[buffer(1)]],
 device vec<uchar, savedRefs> *relativeOffsets [[buffer(2)]],
 device uint *smallCounterMetadata1 [[buffer(3)]],
 device atomic_uint *smallCounterMetadata2 [[buffer(4)]],
 device uint *smallAtomReferences [[buffer(5)]],
 uint tid [[thread_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Allocate memory for the relative offsets.
  threadgroup uchar cachedRelativeOffsets[savedRefs * 128];
  
  // Materialize the atom.
  float4 atom = convertedAtoms[tid];
  
  // Place the atom in the grid of small cells.
  atom.xyz = 4 * (atom.xyz - bvhArgs->worldMinimum);
  atom.w = 4 * atom.w;
  
  // Generate the bounding box.
  ushort3 loopStart;
  ushort3 loopEnd;
  {
    short3 smallVoxelMin = short3(floor(atom.xyz - atom.w));
    short3 smallVoxelMax = short3(ceil(atom.xyz + atom.w));
    
    ushort3 gridDims = bvhArgs->smallVoxelCount;
    loopStart = clamp(smallVoxelMin, gridDims);
    loopEnd = clamp(smallVoxelMax, gridDims);
  }
  
  // Reorder the loop traversal.
  ushort permutationID = pickPermutation(loopEnd - loopStart);
  loopStart = reorderForward(loopStart, permutationID);
  loopEnd = reorderForward(loopEnd, permutationID);
  
  {
    // Read from device memory.
    vec<uchar, savedRefs> input;
    input = relativeOffsets[tid];
    
    // Store the cached offsets.
    simdgroup_barrier(mem_flags::mem_threadgroup);
#pragma clang loop unroll(full)
    for (ushort i = 0; i < savedRefs; ++i) {
      ushort address = i;
      address = address * 128 + thread_id;
      uchar offset = input[i];
      cachedRelativeOffsets[address] = offset;
    }
  }
  
  // Iterate over the footprint on the 3D grid.
  simdgroup_barrier(mem_flags::mem_threadgroup);
  ushort offsetCursor = 0;
  for (ushort z = loopStart[2]; z < loopEnd[2]; ++z) {
    for (ushort y = loopStart[1]; y < loopEnd[1]; ++y) {
      for (ushort x = loopStart[0]; x < loopEnd[0]; ++x) {
        ushort3 actualXYZ = ushort3(x, y, z);
        actualXYZ = reorderBackward(actualXYZ, permutationID);
        
        // Narrow down the cells with a cube-sphere intersection test.
        bool intersected = cubeSphereIntersection(actualXYZ, atom);
        if (!intersected) {
          continue;
        }
        
        // Generate the address.
        ushort3 gridDims = bvhArgs->smallVoxelCount;
        uint address = VoxelAddress::generate(gridDims, actualXYZ);
        
        // Branch on whether the cache has overflowed.
        uint offset;
        if (offsetCursor < savedRefs) {
          offset = smallCounterMetadata1[address];
        } else {
          offset = atomic_fetch_add_explicit(smallCounterMetadata2 + address,
                                             1, memory_order_relaxed);
        }
        
        // Add the atom offset.
        if (offsetCursor < savedRefs) {
          ushort address = offsetCursor;
          address = address * 128 + thread_id;
          offsetCursor += 1;
          
          uchar relativeOffset = cachedRelativeOffsets[address];
          offset += relativeOffset;
        }
        
        // Write the reference to the list.
        smallAtomReferences[offset] = tid;
      }
    }
  }
}
