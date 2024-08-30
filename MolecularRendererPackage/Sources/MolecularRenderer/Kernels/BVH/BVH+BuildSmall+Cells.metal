//
//  BVH+BuildSmall+Cells.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/30/24.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "../Utilities/VoxelAddress.metal"
using namespace metal;

// Encode the GPU-driven work in this pass.
kernel void buildSmallPart1_0
(
 // Global counters.
 device uint3 *allocatedMemory [[buffer(0)]],
 device int3 *boundingBoxMin [[buffer(1)]],
 device int3 *boundingBoxMax [[buffer(2)]],
 
 // Indirect dispatch arguments.
 device BVHArguments *bvhArgs [[buffer(3)]],
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
  
  // Set the small-cell dispatch arguments.
  *smallCellDispatchArguments8x8x8 = uint3(largeVoxelCount);
}

kernel void clearSmallCellMetadata
(
 constant BVHArguments *bvhArgs [[buffer(0)]],
 device uint4 *smallCellMetadata [[buffer(1)]],
 
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort3 thread_id [[thread_position_in_threadgroup]])
{
  ushort3 cellCoordinates = tgid * 8;
  cellCoordinates += thread_id * ushort3(4, 1, 1);
  uint cellAddress = VoxelAddress::generate(bvhArgs->smallVoxelCount,
                                            cellCoordinates);
  smallCellMetadata[cellAddress / 4] = uint4(0);
}
