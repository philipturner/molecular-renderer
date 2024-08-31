//
//  BVH+BuildLarge+Atoms.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/26/24.
//

#include <metal_stdlib>
#include "../Utilities/VoxelAddress.metal"
using namespace metal;

// Convert the atom from 'float4' to a custom format.
inline float4 convert(float4 atom, constant float *elementRadii) {
  uint atomicNumber = uint(atom.w);
  float radius = elementRadii[atomicNumber];
  
  uint packed = as_type<uint>(radius);
  packed = packed & 0xFFFFFF00;
  packed |= atomicNumber & 0x000000FF;
  
  float4 output = atom;
  output.w = as_type<float>(packed);
  return output;
}

inline ushort3 clamp(short3 position, ushort3 gridDims) {
  short3 output = position;
  output = clamp(output, 0, short3(gridDims));
  return ushort3(output);
}

inline ushort pickPermutation(short3 footprintHigh) {
  ushort output;
  if (footprintHigh[0] == 0) {
    output = 0;
  } else if (footprintHigh[1] == 0) {
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

// MARK: - Kernels

kernel void buildLargePart1_1
(
 constant float *elementRadii [[buffer(0)]],
 device float4 *originalAtoms [[buffer(1)]],
 device ushort4 *relativeOffsets1 [[buffer(2)]],
 device ushort4 *relativeOffsets2 [[buffer(3)]],
 device atomic_uint *largeCounterMetadata [[buffer(4)]],
 uint tid [[thread_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Materialize the atom.
  float4 atom = originalAtoms[tid];
  atom = convert(atom, elementRadii);
  
  // Place the atom in the grid of small cells.
  atom.xyz = 4 * (atom.xyz + 64);
  atom.w = 4 * atom.w;
  
  // Generate the bounding box.
  short3 boxMin = short3(floor(atom.xyz - atom.w));
  short3 boxMax = short3(ceil(atom.xyz + atom.w));
  ushort3 gridDims = ushort3(512);
  ushort3 smallVoxelMin = clamp(boxMin, gridDims);
  ushort3 smallVoxelMax = clamp(boxMax, gridDims);
  ushort3 largeVoxelMin = smallVoxelMin / 8;
  
  // Pre-compute the footprint.
  ushort3 dividingLine = (largeVoxelMin + 1) * 8;
  dividingLine = min(dividingLine, smallVoxelMax);
  dividingLine = max(dividingLine, smallVoxelMin);
  short3 footprintLow = short3(dividingLine - smallVoxelMin);
  short3 footprintHigh = short3(smallVoxelMax - dividingLine);
  
  // Determine the loop bounds.
  ushort3 loopEnd = select(ushort3(1),
                           ushort3(2),
                           footprintHigh > 0);
  
  // Reorder the loop traversal.
  ushort permutationID = pickPermutation(footprintHigh);
  loopEnd = reorderForward(loopEnd, permutationID);
  
  // Allocate memory for the relative offsets.
  threadgroup ushort cachedRelativeOffsets[8 * 128];
  
  // Iterate over the footprint on the 3D grid.
  for (ushort z = 0; z < loopEnd[2]; ++z) {
    for (ushort y = 0; y < loopEnd[1]; ++y) {
      for (ushort x = 0; x < loopEnd[0]; ++x) {
        ushort3 actualXYZ = ushort3(x, y, z);
        actualXYZ = reorderBackward(actualXYZ, permutationID);
        
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
          offset = atomic_fetch_add_explicit(largeCounterMetadata + address,
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
  
  {
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
}

kernel void buildLargePart2_2
(
 constant float *elementRadii [[buffer(0)]],
 device float4 *originalAtoms [[buffer(1)]],
 device ushort4 *relativeOffsets1 [[buffer(2)]],
 device ushort4 *relativeOffsets2 [[buffer(3)]],
 device float4 *convertedAtoms [[buffer(4)]],
 device uint *largeCounterMetadata [[buffer(5)]],
 device uint *largeAtomReferences [[buffer(6)]],
 uint tid [[thread_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Materialize the atom.
  float4 atom = originalAtoms[tid];
  atom = convert(atom, elementRadii);
  
  // Write in the new format.
  convertedAtoms[tid] = atom;
  
  // Place the atom in the grid of small cells.
  atom.xyz = 4 * (atom.xyz + 64);
  atom.w = 4 * atom.w;
  
  // Generate the bounding box.
  short3 boxMin = short3(floor(atom.xyz - atom.w));
  short3 boxMax = short3(ceil(atom.xyz + atom.w));
  ushort3 gridDims = ushort3(512);
  ushort3 smallVoxelMin = clamp(boxMin, gridDims);
  ushort3 smallVoxelMax = clamp(boxMax, gridDims);
  ushort3 largeVoxelMin = smallVoxelMin / 8;
  
  // Pre-compute the footprint.
  ushort3 dividingLine = (largeVoxelMin + 1) * 8;
  dividingLine = min(dividingLine, smallVoxelMax);
  dividingLine = max(dividingLine, smallVoxelMin);
  short3 footprintHigh = short3(smallVoxelMax - dividingLine);
  
  // Determine the loop bounds.
  ushort3 loopEnd = select(ushort3(1),
                           ushort3(2),
                           footprintHigh > 0);
  
  // Reorder the loop traversal.
  ushort permutationID = pickPermutation(footprintHigh);
  loopEnd = reorderForward(loopEnd, permutationID);
  
  // Allocate memory for the relative offsets.
  threadgroup ushort cachedRelativeOffsets[8 * 128];
  
  {
    // Read from device memory.
    ushort4 input[2];
    input[0] = relativeOffsets1[tid];
    if (loopEnd[2] == 2) {
      input[1] = relativeOffsets2[tid];
    }
    
    // Store the cached offsets.
#pragma clang loop unroll(full)
    for (ushort i = 0; i < 8; ++i) {
      ushort address = i;
      address = address * 128 + thread_id;
      ushort offset = input[i / 4][i % 4];
      cachedRelativeOffsets[address] = offset;
    }
  }
  
  // Iterate over the footprint on the 3D grid.
  simdgroup_barrier(mem_flags::mem_threadgroup);
  for (ushort z = 0; z < loopEnd[2]; ++z) {
    for (ushort y = 0; y < loopEnd[1]; ++y) {
      for (ushort x = 0; x < loopEnd[0]; ++x) {
        ushort3 actualXYZ = ushort3(x, y, z);
        actualXYZ = reorderBackward(actualXYZ, permutationID);
        
        // Read the compacted cell offset.
        uint offset;
        {
          ushort3 gridDims = ushort3(64);
          ushort3 cubeMin = ushort3(largeVoxelMin) + actualXYZ;
          uint address = VoxelAddress::generate(gridDims, cubeMin);
          address = (address * 8) + (tid % 8);
          
          offset = largeCounterMetadata[address];
        }
        
        // Add the atom offset.
        {
          ushort address = z * 4 + y * 2 + x;
          address = address * 128 + thread_id;
          ushort relativeOffset = cachedRelativeOffsets[address];
          offset += relativeOffset;
        }
        
        // Write the reference to the list.
        largeAtomReferences[offset] = tid;
      }
    }
  }
}
