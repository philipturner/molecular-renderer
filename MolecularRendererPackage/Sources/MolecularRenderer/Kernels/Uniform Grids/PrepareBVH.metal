//
//  PrepareBVH.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/18/24.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
using namespace metal;

// Fills the memory allocation with the specified pattern.
kernel void resetMemory1D
(
 device uint *b [[buffer(0)]],
 constant uint &pattern [[buffer(1)]],
 
 uint tid [[thread_position_in_grid]])
{
  b[tid] = pattern;
}

// Converts the float4 atoms to two different formats (for now).
kernel void convert
(
 device float4 *originalAtoms [[buffer(0)]],
 device float *atomRadii [[buffer(1)]],
 device float4 *convertedAtoms [[buffer(2)]],
 
 uint tid [[thread_position_in_grid]])
{
  // Fetch the atom from memory.
  float4 atom = originalAtoms[tid];
  
  // Write the new format.
  {
    ushort atomicNumber = ushort(atom[3]);
    float radius = atomRadii[atomicNumber];
    
    uint packed = as_type<uint>(radius);
    packed = packed & 0xFFFFFF00;
    packed = packed | atomicNumber;
    
    float4 convertedAtom = atom;
    convertedAtom.w = as_type<float>(packed);
    convertedAtoms[tid] = convertedAtom;
  }
}

// Condense the per-atom boxes a smaller O(n) list of partials.
kernel void reduceBBPart1
(
 constant uint &atomCount [[buffer(0)]],
 device float4 *convertedAtoms [[buffer(1)]],
 device int3 *partials [[buffer(2)]],
 
 uint tgid [[threadgroup_position_in_grid]],
 ushort thread_id [[thread_position_in_threadgroup]])
{
  // Fetch the atom from memory.
  uint atomID = tgid * 128 + thread_id;
  atomID = min(atomID, atomCount - 1);
  float4 atom = convertedAtoms[atomID];
  
  // Compute the bounding box.
  float3 minimum = atom.xyz - atom.w;
  float3 maximum = atom.xyz + atom.w;
  minimum = 2 * floor(minimum / 2);
  maximum = 2 * ceil(maximum / 2);
  
  // Write something to memory.
  int3 minimumInt = int3(minimum);
  int3 maximumInt = int3(maximum);
  partials[2 * tgid + 0] = minimumInt;
  partials[2 * tgid + 1] = maximumInt;
}

// A single GPU thread encodes some GPU-driven work.
kernel void setIndirectArguments
(
 device int3 *boundingBoxMin [[buffer(0)]],
 device int3 *boundingBoxMax [[buffer(1)]],
 device BVHArguments *bvhArgs [[buffer(2)]],
 device uint3 *smallCellDispatchArguments [[buffer(3)]])
{
  // Read the bounding box.
  int3 minimum = *boundingBoxMin;
  int3 maximum = *boundingBoxMax;
  
  // Clamp the bounding box to the world volume.
  minimum = max(minimum, -64);
  maximum = min(maximum, 64);
  
  // Prevent undefined behavior when no atoms are present.
  maximum = max(maximum, minimum);
  
  // Set the BVH arguments.
  {
    ushort3 gridDimensions = ushort3(4 * (maximum - minimum));
    bvhArgs->worldMinimum = float3(minimum);
    bvhArgs->worldMaximum = float3(maximum);
    bvhArgs->smallVoxelCount = gridDimensions;
  }
  
  // Set the small-cell dispatch arguments.
  {
    ushort3 gridDimensions = ushort3(4 * (maximum - minimum));
    
    uint smallVoxelCount = 1;
    smallVoxelCount *= uint(gridDimensions[0]);
    smallVoxelCount *= uint(gridDimensions[1]);
    smallVoxelCount *= uint(gridDimensions[2]);
    
    uint threadgroupCount = (smallVoxelCount + 127) / 128;
    *smallCellDispatchArguments = { threadgroupCount, 1, 1 };
  }
}
