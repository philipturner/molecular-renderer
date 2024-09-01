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

class VoxelAddress {
public:
  static uint generate(ushort3 grid_dims, ushort3 coords) {
    uint grid_width_sq = grid_dims.y * grid_dims.x;
    return coords.z * grid_width_sq + coords.y * grid_dims.x + coords.x;
  }
};

#endif // VOXEL_ADDRESS_H
