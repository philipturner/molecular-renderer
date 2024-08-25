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
