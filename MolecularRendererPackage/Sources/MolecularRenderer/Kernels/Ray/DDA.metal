//
//  DDA.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/4/23.
//

#ifndef DDA_H
#define DDA_H

#include <metal_stdlib>
#include "../Ray/Ray.metal"
#include "../Utilities/Constants.metal"
#include "../Utilities/VoxelAddress.metal"
using namespace metal;
using namespace raytracing;

// Sources:
// - https://tavianator.com/2022/ray_box_boundary.html
// - https://ieeexplore.ieee.org/document/7349894
class DDA {
  float3 dt;
  float3 t;
  ushort3 position;
  
  // Progress of the adjusted ray w.r.t. the original ray. This ensures closest
  // hits are recognized in the correct order.
  float tmin; // in the original coordinate space
  float voxel_tmax; // in the relative coordinate space
  
public:
  ushort3 grid_dims;
  uint address;
  bool continue_loop;
  
  DDA(float3 rayOrigin, 
      float3 rayDirection,
      constant BVHArguments *bvhArgs)
  {
    float3 transformedRayOrigin;
    transformedRayOrigin = 4 * (rayOrigin - bvhArgs->worldMinimum);
    grid_dims = bvhArgs->smallVoxelCount;
    
    float tmin = 0;
    float tmax = INFINITY;
    dt = precise::divide(1, rayDirection);
    
    // Perform a ray-box intersection test.
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      float t1 = (0 - transformedRayOrigin[i]) * dt[i];
      float t2 = (float(grid_dims[i]) - transformedRayOrigin[i]) * dt[i];
      tmin = max(tmin, min(min(t1, t2), tmax));
      tmax = min(tmax, max(max(t1, t2), tmin));
    }
    
    // Adjust the origin so it starts in the grid.
    // NOTE: This translates `t` by an offset of `tmin`.
    continue_loop = (tmin < tmax);
    transformedRayOrigin += tmin * rayDirection;
    transformedRayOrigin = max(transformedRayOrigin, float3(0));
    transformedRayOrigin = min(transformedRayOrigin, float3(grid_dims));
    this->tmin = tmin * 0.25;
    
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      float origin = transformedRayOrigin[i];
      
      if (rayDirection[i] < 0) {
        origin = float(grid_dims[i]) - origin;
      }
      position[i] = ushort(origin);
      
      // `t` is actually the future `t`. When incrementing each dimension's `t`,
      // which one will produce the smallest `t`? This dimension gets the
      // increment because we want to intersect the closest voxel, which hasn't
      // been tested yet.
      t[i] = (floor(origin) - origin) * abs(dt[i]) + abs(dt[i]);
    }
    
    ushort3 neg_position = grid_dims - 1 - position;
    ushort3 actual_position = select(position, neg_position, dt < 0);
    address = VoxelAddress::generate(grid_dims, actual_position);
  }
  
  float get_max_accepted_t() {
    return tmin + voxel_tmax * 0.25;
  }
  
  void increment_position() {
    ushort2 cond_mask;
    cond_mask[0] = (t.x < t.y) ? 1 : 0;
    cond_mask[1] = (t.x < t.z) ? 1 : 0;
    uint desired = as_type<uint>(ushort2(1, 1));
    
    if (as_type<uint>(cond_mask) == desired) {
      voxel_tmax = t.x; // actually t + dt
      address += VoxelAddress::increment_x(grid_dims, dt.x < 0);
      t.x += abs(dt.x); // actually t + dt + dt
      
      position.x += 1;
      continue_loop = (position.x < grid_dims.x);
    } else if (t.y < t.z) {
      voxel_tmax = t.y;
      address += VoxelAddress::increment_y(grid_dims, dt.y < 0);
      t.y += abs(dt.y);
      
      position.y += 1;
      continue_loop = (position.y < grid_dims.y);
    } else {
      voxel_tmax = t.z;
      address += VoxelAddress::increment_z(grid_dims, dt.z < 0);
      t.z += abs(dt.z);
      
      position.z += 1;
      continue_loop = (position.z < grid_dims.z);
    }
  }
};

#endif // DDA_H
