//
//  VoxelAddress.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/24/24.
//

#ifndef VOXEL_ADDRESS_H
#define VOXEL_ADDRESS_H

#include <metal_stdlib>
using namespace metal;

// Behavior is undefined when the position goes out-of-bounds.
class VoxelAddress {
public:
  static uint generate(ushort3 grid_dims, ushort3 coords) {
    uint grid_width_sq = grid_dims.y * grid_dims.x;
    return coords.z * grid_width_sq + coords.y * grid_dims.x + coords.x;
  }
  
  static int increment_x(ushort3 grid_dims, bool negative = false) {
    return select(1, -1, negative);
  }
  
  static int increment_y(ushort3 grid_dims, bool negative = false) {
    short w = short(grid_dims.x);
    return select(w, short(-w), negative);
  }
  
  static int increment_z(ushort3 grid_dims, bool negative = false) {
    int w_sq = grid_dims.y * grid_dims.x;
    return select(w_sq, -w_sq, negative);
  }
};

#endif // VOXEL_ADDRESS_H
