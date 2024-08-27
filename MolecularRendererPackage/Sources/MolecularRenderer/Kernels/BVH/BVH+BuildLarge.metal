//
//  BVH+BuildLarge.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/26/24.
//

#include <metal_stdlib>
using namespace metal;

// Start with a simple function that increments the atom count in
// each large voxel.
// - Multiple separate kernels for the time being.
// - Later, fuse into a single kernel and prove there's a speedup.
