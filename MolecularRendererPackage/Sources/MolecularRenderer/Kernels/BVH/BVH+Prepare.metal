//
//  BVH+Prepare.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/18/24.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
using namespace metal;

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
kernel void reduceBoxPart1
(
 constant uint &atomCount [[buffer(0)]],
 device float4 *convertedAtoms [[buffer(1)]],
 device int3 *partials [[buffer(2)]],
 
 uint tgid [[threadgroup_position_in_grid]],
 ushort thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
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
  threadgroup_barrier(mem_flags::mem_threadgroup);
  threadgroup int3 threadgroupMinimum[4];
  threadgroup int3 threadgroupMaximum[4];
  if (lane_id == 0) {
    threadgroupMinimum[simd_id] = minimum;
    threadgroupMaximum[simd_id] = maximum;
  }
  
  // Reduce across the SIMD.
  threadgroup_barrier(mem_flags::mem_threadgroup);
  if (thread_id < 32) {
    minimum = threadgroupMinimum[thread_id % 4];
    minimum = simd_min(minimum);
  } else if (thread_id < 64) {
    maximum = threadgroupMaximum[thread_id % 4];
    maximum = simd_max(maximum);
  }
  
  // Store the result to memory.
  if (lane_id == 0) {
    if (simd_id == 0) {
      partials[2 * tgid + 0] = minimum;
    } else if (simd_id == 1) {
      partials[2 * tgid + 1] = maximum;
    }
  }
}

// Utility for distributing different vector lanes to different threads.
inline int vectorSelect(int3 vector, ushort lane) {
  if (lane == 0) {
    return vector[0];
  } else if (lane == 1) {
    return vector[1];
  } else if (lane == 2) {
    return vector[2];
  } else {
    return 0;
  }
}

// Reduce the smaller list with atomics.
kernel void reduceBoxPart2
(
 constant uint &partialCount [[buffer(0)]],
 device int3 *partials [[buffer(1)]],
 device atomic_int *boundingBoxCounters [[buffer(2)]],
 
 uint tgid [[threadgroup_position_in_grid]],
 ushort thread_id [[thread_position_in_threadgroup]],
 ushort lane_id [[thread_index_in_simdgroup]],
 ushort simd_id [[simdgroup_index_in_threadgroup]])
{
  // Fetch the partial from memory.
  uint partialID = tgid * 128 + thread_id;
  partialID = min(partialID, partialCount - 1);
  int3 minimum = partials[2 * partialID + 0];
  int3 maximum = partials[2 * partialID + 1];
  
  // Reduce across the SIMD.
  minimum = simd_min(minimum);
  maximum = simd_max(maximum);
  
  // Reduce across the threadgroup.
  threadgroup int3 threadgroupMinimum[4];
  threadgroup int3 threadgroupMaximum[4];
  if (lane_id == 0) {
    threadgroupMinimum[simd_id] = minimum;
    threadgroupMaximum[simd_id] = maximum;
  }
  
  // Reduce across the SIMD.
  threadgroup_barrier(mem_flags::mem_threadgroup);
  if (thread_id < 32) {
    minimum = threadgroupMinimum[thread_id % 4];
    minimum = simd_min(minimum);
  } else if (thread_id < 64) {
    maximum = threadgroupMaximum[thread_id % 4];
    maximum = simd_max(maximum);
  }
  
  // Store the result to memory.
  if (lane_id < 3) {
    if (simd_id == 0) {
      int minimumScalar = vectorSelect(minimum, lane_id);
      atomic_fetch_min_explicit(boundingBoxCounters + lane_id,
                                minimumScalar, memory_order_relaxed);
    } else if (simd_id == 1) {
      int maximumScalar = vectorSelect(maximum, lane_id);
      atomic_fetch_max_explicit(boundingBoxCounters + 4 + lane_id,
                                maximumScalar, memory_order_relaxed);
    }
  }
}

// A single GPU thread encodes some GPU-driven work.
kernel void setIndirectArguments
(
 device int3 *boundingBoxMin [[buffer(0)]],
 device int3 *boundingBoxMax [[buffer(1)]],
 device BVHArguments *bvhArgs [[buffer(2)]],
 device uint3 *smallCellDispatchArguments128x1x1 [[buffer(3)]],
 device uint3 *smallCellDispatchArguments8x8x8 [[buffer(4)]])
{
  // Read the bounding box.
  int3 minimum = *boundingBoxMin;
  int3 maximum = *boundingBoxMax;
  
  // Clamp the bounding box to the world volume.
  minimum = max(minimum, -64);
  maximum = min(maximum, 64);
  maximum = max(minimum, maximum);
  
  // Compute the grid dimensions.
  ushort3 largeVoxelCount = ushort3((maximum - minimum) / 2);
  ushort3 smallVoxelCount = ushort3(4 * (maximum - minimum));
  
  // Set the BVH arguments.
  bvhArgs->worldMinimum = float3(minimum);
  bvhArgs->worldMaximum = float3(maximum);
  bvhArgs->largeVoxelCount = largeVoxelCount;
  bvhArgs->smallVoxelCount = smallVoxelCount;
  
  // Set the small-cell dispatch arguments (128x1x1).
  {
    uint cellCount = 1;
    cellCount *= smallVoxelCount[0];
    cellCount *= smallVoxelCount[1];
    cellCount *= smallVoxelCount[2];
    
    uint threadgroupCount = (cellCount + 127) / 128;
    *smallCellDispatchArguments128x1x1 = { threadgroupCount, 1, 1 };
  }
  
  // Set the small-cell dispatch arguments (8x8x8).
  *smallCellDispatchArguments8x8x8 = uint3(largeVoxelCount);
}
