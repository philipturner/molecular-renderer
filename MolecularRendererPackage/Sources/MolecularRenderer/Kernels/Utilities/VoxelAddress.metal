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
  static uint generate(vec<ushort, 3> grid_dims,
                       vec<ushort, 3> coords)
  {
    uint grid_width_sq = grid_dims.y * grid_dims.x;
    return coords.z * grid_width_sq + coords.y * grid_dims.x + coords.x;
  }
  
  static half generate(vec<half, 3> grid_dims,
                       vec<half, 3> coords)
  {
    half grid_width_sq = grid_dims.y * grid_dims.x;
    return coords.z * grid_width_sq + coords.y * grid_dims.x + coords.x;
  }
  
  static float generate(vec<float, 3> grid_dims,
                        vec<float, 3> coords)
  {
    float grid_width_sq = grid_dims.y * grid_dims.x;
    return coords.z * grid_width_sq + coords.y * grid_dims.x + coords.x;
  }
};

#endif // VOXEL_ADDRESS_H
