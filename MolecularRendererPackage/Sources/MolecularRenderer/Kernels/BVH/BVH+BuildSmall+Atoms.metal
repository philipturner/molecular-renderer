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

inline ushort3 clamp(float3 position, ushort3 gridDims) {
  short3 output = short3(position);
  output = clamp(output, 0, short3(gridDims));
  return ushort3(output);
}

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
 device uint4 *largeCellMetadata [[buffer(1)]],
 device uint *largeAtomReferences [[buffer(2)]],
 device float4 *convertedAtoms [[buffer(3)]],
 device atomic_uint *smallCounterMetadata [[buffer(4)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Materialize the lower corner in registers.
  float3 lowerCorner = bvhArgs->worldMinimum;
  lowerCorner += float3(tgid) * 2;
  lowerCorner += 64;
  
  // Locate the threadgroup's metadata.
  ushort3 cellCoordinates = ushort3(lowerCorner);
  cellCoordinates /= 2;
  ushort3 gridDims = ushort3(64);
  uint cellAddress = VoxelAddress::generate(gridDims, cellCoordinates);
  
  // Read the threadgroup's metadata.
  uint4 cellMetadata = largeCellMetadata[cellAddress];
  uint largeReferenceOffset = cellMetadata[1];
  ushort largeReferenceCount = cellMetadata[3] & (uint(1 << 14) - 1);
  
  // Iterate over the large voxel's atoms.
  ushort smallAtomID = thread_id;
  for (; smallAtomID < largeReferenceCount; smallAtomID += 128) {
    // Materialize the atom.
    uint largeReferenceID = largeReferenceOffset + smallAtomID;
    uint largeAtomID = largeAtomReferences[largeReferenceID];
    float4 atom = convertedAtoms[largeAtomID];
    
    // Generate the bounding box.
    ushort3 loopStart;
    ushort3 loopEnd;
    {
      float3 smallVoxelMin = atom.xyz - atom.w;
      float3 smallVoxelMax = atom.xyz + atom.w;
      smallVoxelMin = 4 * (smallVoxelMin - bvhArgs->worldMinimum);
      smallVoxelMax = 4 * (smallVoxelMax - bvhArgs->worldMinimum);
      smallVoxelMin = floor(smallVoxelMin);
      smallVoxelMax = ceil(smallVoxelMax);
      
      ushort3 gridDims = bvhArgs->smallVoxelCount;
      loopStart = clamp(smallVoxelMin, gridDims);
      loopEnd = clamp(smallVoxelMax, gridDims);
    }
    
    // Place the atom in the grid of small cells.
    atom.xyz = 4 * (atom.xyz - bvhArgs->worldMinimum);
    atom.w = 4 * atom.w;
    
    // Iterate over the footprint on the 3D grid.
    for (ushort z = loopStart[2]; z < loopEnd[2]; ++z) {
      for (ushort y = loopStart[1]; y < loopEnd[1]; ++y) {
        for (ushort x = loopStart[0]; x < loopEnd[0]; ++x) {
          ushort3 actualXYZ = ushort3(x, y, z);
          
          // Narrow down the cells with a cube-sphere intersection test.
          bool intersected = cubeSphereIntersection(actualXYZ, atom);
          if (!intersected) {
            continue;
          }
          
          // Generate the address.
          ushort3 gridDims = bvhArgs->smallVoxelCount;
          uint address = VoxelAddress::generate(gridDims, actualXYZ);
          
          // Perform the atomic fetch-add.
          atomic_fetch_add_explicit(smallCounterMetadata + address,
                                    1, memory_order_relaxed);
        }
      }
    }
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
 device uint4 *largeCellMetadata [[buffer(1)]],
 device uint *largeAtomReferences [[buffer(2)]],
 device float4 *convertedAtoms [[buffer(3)]],
 device atomic_uint *smallCounterMetadata [[buffer(4)]],
 device uint *smallAtomReferences [[buffer(5)]],
 ushort3 tgid [[threadgroup_position_in_grid]],
 ushort thread_id [[thread_index_in_threadgroup]])
{
  // Materialize the lower corner in registers.
  float3 lowerCorner = bvhArgs->worldMinimum;
  lowerCorner += float3(tgid) * 2;
  lowerCorner += 64;
  
  // Locate the threadgroup's metadata.
  ushort3 cellCoordinates = ushort3(lowerCorner);
  cellCoordinates /= 2;
  ushort3 gridDims = ushort3(64);
  uint cellAddress = VoxelAddress::generate(gridDims, cellCoordinates);
  
  // Read the threadgroup's metadata.
  uint4 cellMetadata = largeCellMetadata[cellAddress];
  uint largeReferenceOffset = cellMetadata[1];
  ushort largeReferenceCount = cellMetadata[3] & (uint(1 << 14) - 1);
  
  // Iterate over the large voxel's atoms.
  ushort smallAtomID = thread_id;
  for (; smallAtomID < largeReferenceCount; smallAtomID += 128) {
    // Materialize the atom.
    uint largeReferenceID = largeReferenceOffset + smallAtomID;
    uint largeAtomID = largeAtomReferences[largeReferenceID];
    float4 atom = convertedAtoms[largeAtomID];
    
    // Generate the bounding box.
    ushort3 loopStart;
    ushort3 loopEnd;
    {
      float3 smallVoxelMin = atom.xyz - atom.w;
      float3 smallVoxelMax = atom.xyz + atom.w;
      smallVoxelMin = 4 * (smallVoxelMin - bvhArgs->worldMinimum);
      smallVoxelMax = 4 * (smallVoxelMax - bvhArgs->worldMinimum);
      smallVoxelMin = floor(smallVoxelMin);
      smallVoxelMax = ceil(smallVoxelMax);
      
      ushort3 gridDims = bvhArgs->smallVoxelCount;
      loopStart = clamp(smallVoxelMin, gridDims);
      loopEnd = clamp(smallVoxelMax, gridDims);
    }
    
    // Place the atom in the grid of small cells.
    atom.xyz = 4 * (atom.xyz - bvhArgs->worldMinimum);
    atom.w = 4 * atom.w;
    
    // Iterate over the footprint on the 3D grid.
    for (ushort z = loopStart[2]; z < loopEnd[2]; ++z) {
      for (ushort y = loopStart[1]; y < loopEnd[1]; ++y) {
        for (ushort x = loopStart[0]; x < loopEnd[0]; ++x) {
          ushort3 actualXYZ = ushort3(x, y, z);
          
          // Narrow down the cells with a cube-sphere intersection test.
          bool intersected = cubeSphereIntersection(actualXYZ, atom);
          if (!intersected) {
            continue;
          }
          
          // Generate the address.
          ushort3 gridDims = bvhArgs->smallVoxelCount;
          uint address = VoxelAddress::generate(gridDims, actualXYZ);
          
          // Perform the atomic fetch-add.
          uint offset =
          atomic_fetch_add_explicit(smallCounterMetadata + address,
                                    1, memory_order_relaxed);
          
          // Write the reference to the list.
          smallAtomReferences[offset] = largeAtomID;
        }
      }
    }
  }
}
