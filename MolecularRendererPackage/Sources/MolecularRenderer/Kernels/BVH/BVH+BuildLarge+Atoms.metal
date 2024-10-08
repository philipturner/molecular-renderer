//
//  BVH+BuildLarge+Atoms.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/26/24.
//

#include <metal_stdlib>
#include "../Utilities/VoxelAddress.metal"
#include "../Utilities/WorldVolume.metal"
using namespace metal;

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

kernel void buildLargePart0_1
(
 constant half *elementRadii [[buffer(1)]],
 device float4 *currentAtoms [[buffer(3)]],
 device ushort4 *relativeOffsets1 [[buffer(4)]],
 device ushort4 *relativeOffsets2 [[buffer(5)]],
 
 device uchar *cellGroupMarks [[buffer(6)]],
 device atomic_uint *largeCounterMetadata [[buffer(7)]],
 uint tid [[thread_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Materialize the atom.
  float4 atom = currentAtoms[tid];
  ushort atomicNumber = ushort(atom.w);
  half radius = elementRadii[atomicNumber];
  
  // Place the atom in the grid of small cells.
  float3 scaledPosition = atom.xyz + float(worldVolumeInNm / 2);
  scaledPosition /= 0.25;
  float scaledRadius = radius / 0.25;
  
  // Generate the bounding box.
  float3 boxMin = floor(scaledPosition - scaledRadius);
  float3 boxMax = ceil(scaledPosition + scaledRadius);
  
  // Return early if out of bounds.
  if (any(boxMin < 0 ||
          boxMax > float(smallVoxelGridWidth))) {
    return;
  }
  
  // Generate the voxel coordinates.
  ushort3 smallVoxelMin = ushort3(boxMin);
  ushort3 smallVoxelMax = ushort3(boxMax);
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
          ushort3 cellCoordinates = largeVoxelMin + actualXYZ;
          uint address = VoxelAddress::generate(largeVoxelGridWidth,
                                                cellCoordinates);
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
        
        // Write the cell-group mark.
        {
          // Locate the mark.
          ushort3 cellCoordinates = largeVoxelMin + actualXYZ;
          cellCoordinates /= 4;
          uint address = VoxelAddress::generate(cellGroupGridWidth,
                                                cellCoordinates);
          
          // Write the mark.
          uchar activeValue = uchar(1);
          cellGroupMarks[address] = activeValue;
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

kernel void buildLargePart1_1
(
 constant bool *useAtomMotionVectors [[buffer(0)]],
 constant half *elementRadii [[buffer(1)]],
 device float4 *previousAtoms [[buffer(2)]],
 device float4 *currentAtoms [[buffer(3)]],
 device ushort4 *relativeOffsets1 [[buffer(4)]],
 device ushort4 *relativeOffsets2 [[buffer(5)]],
 
 device half3 *atomMetadata [[buffer(6)]],
 device half4 *convertedAtoms [[buffer(7)]],
 device uint *largeAtomReferences [[buffer(8)]],
 device uint *largeCounterMetadata [[buffer(9)]],
 uint tid [[thread_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Materialize the atom.
  float4 atom = currentAtoms[tid];
  ushort atomicNumber = ushort(atom.w);
  float radius = elementRadii[atomicNumber];
  
  // Write the atom metadata.
  {
    float4 previousAtom;
    if (*useAtomMotionVectors) {
      previousAtom = previousAtoms[tid];
    } else {
      previousAtom = atom;
    }
    
    half3 metadata;
    metadata.xyz = half3(atom.xyz - previousAtom.xyz);
    atomMetadata[tid] = metadata;
  }
  
  // Place the atom in the grid of small cells.
  float3 scaledPosition = atom.xyz + float(worldVolumeInNm / 2);
  scaledPosition /= 0.25;
  half scaledRadius = radius / 0.25;
  
  // Generate the bounding box.
  float3 boxMin = floor(scaledPosition - scaledRadius);
  float3 boxMax = ceil(scaledPosition + scaledRadius);
  
  // Return early if out of bounds.
  if (any(boxMin < 0 ||
          boxMax > float(smallVoxelGridWidth))) {
    return;
  }
  
  // Generate the voxel coordinates.
  ushort3 smallVoxelMin = ushort3(boxMin);
  ushort3 smallVoxelMax = ushort3(boxMax);
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
          // Locate the large counter.
          ushort3 cellCoordinates = largeVoxelMin + actualXYZ;
          uint address = VoxelAddress::generate(largeVoxelGridWidth,
                                                cellCoordinates);
          address = (address * 8) + (tid % 8);
          
          // Read from the large counter.
          offset = largeCounterMetadata[address];
        }
        
        // Add the atom's relative offset.
        {
          ushort address = z * 4 + y * 2 + x;
          address = address * 128 + thread_id;
          ushort relativeOffset = cachedRelativeOffsets[address];
          offset += relativeOffset;
        }
        
        // Write the atom.
        {
          // Materialize the lower corner.
          ushort3 cellCoordinates = largeVoxelMin + actualXYZ;
          float3 lowerCorner = -float(worldVolumeInNm / 2);
          lowerCorner += float3(cellCoordinates) * 2;
          
          // Subtract the lower corner.
          half4 writtenAtom;
          writtenAtom.xyz = half3(atom.xyz - lowerCorner);
          writtenAtom.w = radius;
          convertedAtoms[offset] = writtenAtom;
        }
        
        // Map the new array index to the old one.
        largeAtomReferences[offset] = tid;
      }
    }
  }
}
