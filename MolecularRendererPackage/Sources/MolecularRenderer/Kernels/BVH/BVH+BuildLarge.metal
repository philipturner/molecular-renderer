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
 device ushort8 *relativeOffsets [[buffer(3)]],
 
 uint tid [[thread_position_in_grid]])
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
        
        // Perform the atomic addition.
        {
          ushort3 gridDims = bvhArgs->largeVoxelCount;
          ushort3 cubeMin = ushort3(largeVoxelMin) + actualXYZ;
          uint address = VoxelAddress::generate(gridDims, cubeMin);
          address = (address * 8) + (tid % 8);
          
          uint smallReferenceCount =
          footprint[0] * footprint[1] * footprint[2];
          uint word = (smallReferenceCount << 14) + 1;
          atomic_fetch_add_explicit(largeCellMetadata + address,
                                    word, memory_order_relaxed);
        }
      }
    }
  }
}
