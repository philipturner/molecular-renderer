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
  
  // Compute the atom's bounding box.
  int3 minimum;
  int3 maximum;
  {
    float3 lowerCorner = atom.xyz - atom.w;
    float3 upperCorner = atom.xyz + atom.w;
    lowerCorner = 2 * floor(lowerCorner / 2);
    upperCorner = 2 * ceil(upperCorner / 2);
    minimum = int3(lowerCorner);
    maximum = int3(upperCorner);
  }
  
  // Reduce across the SIMD.
  minimum = simd_min(minimum);
  maximum = simd_max(maximum);
  
  // Reduce across the threadgroup.
  threadgroup int3 threadgroupMinimum[8];
  threadgroup int3 threadgroupMaximum[8];
  if (thread_id % 32 == 0) {
    ushort simdIndex = thread_id / 32;
    threadgroupMinimum[simdIndex] = minimum;
    threadgroupMaximum[simdIndex] = maximum;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  // Reduce across the SIMD.
  if (thread_id < 32) {
    minimum = threadgroupMinimum[thread_id % 8];
    maximum = threadgroupMaximum[thread_id % 8];
    minimum = simd_min(minimum);
    maximum = simd_max(maximum);
  }
  
  // Store the result to memory.
  if (thread_id == 0) {
    partials[2 * tgid + 0] = minimum;
    partials[2 * tgid + 1] = maximum;
  }
}

// Reduce the smaller list with atomics.
kernel void reduceBBPart2
(
 constant uint &partialCount [[buffer(0)]],
 device int3 *partials [[buffer(1)]],
 device int3 *boundingBoxCounters [[buffer(2)]],
 
 uint tgid [[threadgroup_position_in_grid]],
 ushort thread_id [[thread_position_in_threadgroup]])
{
  // Fetch the partial from memory.
  uint partialID = tgid * 128 + thread_id;
  partialID = min(partialID, partialCount - 1);
  int3 minimum = partials[2 * partialID + 0];
  int3 maximum = partials[2 * partialID + 1];
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
