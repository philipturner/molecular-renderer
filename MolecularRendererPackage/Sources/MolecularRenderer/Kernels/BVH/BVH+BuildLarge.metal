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

kernel void buildLargePart1
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device atomic_uint *largeCellMetadata [[buffer(1)]],
 device float4 *convertedAtoms [[buffer(2)]],
 device ushort4 *relativeOffsets1 [[buffer(3)]],
 device ushort4 *relativeOffsets2 [[buffer(4)]],
 
 uint tid [[thread_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Transform the atom.
  float4 newAtom = convertedAtoms[tid];
  newAtom.xyz = 4 * (newAtom.xyz - bvhArgs->worldMinimum);
  newAtom.w = 4 * newAtom.w;
  
  // Generate the bounding box.
  short3 smallVoxelMin = short3(floor(newAtom.xyz - newAtom.w));
  short3 smallVoxelMax = short3(ceil(newAtom.xyz + newAtom.w));
  smallVoxelMin = max(smallVoxelMin, 0);
  smallVoxelMax = max(smallVoxelMax, 0);
  smallVoxelMin = min(smallVoxelMin, short3(bvhArgs->smallVoxelCount));
  smallVoxelMax = min(smallVoxelMax, short3(bvhArgs->smallVoxelCount));
  short3 largeVoxelMin = smallVoxelMin / 8;
  
  // Pre-compute the footprint.
  short3 dividingLine = (largeVoxelMin + 1) * 8;
  dividingLine = min(dividingLine, smallVoxelMax);
  dividingLine = max(dividingLine, smallVoxelMin);
  short3 footprintLow = dividingLine - smallVoxelMin;
  short3 footprintHigh = smallVoxelMax - dividingLine;
  
  // Not unrolled             | 103 instructions
  // ALU inefficiency: 16.30% | 67.396 million instructions issued
  // ALU inefficiency: 16.30% | 67.397 million instructions issued
  // ALU inefficiency: 16.30% | 67.396 million instructions issued
  // ~140-160 microseconds
  
  // Unrolled                 | 174 instructions
  // ALU inefficiency: 23.60% | 85.042 million instructions issued
  // ALU inefficiency: 26.01% | 85.041 million instructions issued
  // ALU inefficiency: 25.16% | 85.042 million instructions issued
  // ~150-160 microseconds
  
  // Reordered                | 115 instructions
  // ALU inefficiency: 18.48% | 77.399 million instructions issued
  // ALU inefficiency: 18.48% | 77.398 million instructions issued
  // ALU inefficiency: 18.48% | 77.400 million instructions issued
  // ~90-140 microseconds
  
  // Un-optimized relative offsets
  // 105 microseconds
  // 110 microseconds
  // 130 microseconds
  
  // Fixing the bank conflict
  // 105 microseconds
  // 125 microseconds
  // 105 microseconds
  
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
  for (ushort i = 0; i < 8; ++i) {
    ushort address = i;
    address = address * 128 + thread_id;
    cachedRelativeOffsets[address] = 0xFFFF;
  }
  
  // Iterate over the footprint on the 3D grid.
  simdgroup_barrier(mem_flags::mem_threadgroup);
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
          ushort3 gridDims = bvhArgs->largeVoxelCount;
          ushort3 cubeMin = ushort3(largeVoxelMin) + actualXYZ;
          uint address = VoxelAddress::generate(gridDims, cubeMin);
          address = (address * 8) + (tid % 8);
          
          uint smallReferenceCount =
          footprint[0] * footprint[1] * footprint[2];
          uint word = (smallReferenceCount << 14) + 1;
          
          offset =
          atomic_fetch_add_explicit(largeCellMetadata + address,
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
  
  // Write to device memory.
  //
  // TODO: Perform the 14-masking here. Does it change the instruction count?
  // Before:                           155 instructions
  // After:                            155 instructions
  // All masking instructions removed: 147 instructions
  // Optimized masking:                151 instructions
  constexpr ushort scalarMask = ushort(1 << 14) - 1;
  constexpr uint vectorMask = as_type<uint>(ushort2(scalarMask));
  *((thread uint4*)(output)) &= vectorMask;
  relativeOffsets1[tid] = output[0];// & (ushort(1 << 14) - 1);
  relativeOffsets2[tid] = output[1];// & (ushort(1 << 14) - 1);
}
