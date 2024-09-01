//
//  DDA.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/4/23.
//

#ifndef DDA_H
#define DDA_H

#include <metal_stdlib>
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
  
  // Progress of the adjusted ray w.r.t. the original ray. This ensures closest
  // hits are recognized in the correct order.
  float tmin; // in the original coordinate space
  float voxel_tmax; // in the relative coordinate space
  
public:
  short3 gridDims;
  short3 maybeInvertedPosition;
  
  DDA(float3 rayOrigin, 
      float3 rayDirection,
      constant BVHArguments *bvhArgs,
      thread bool *canIntersectGrid)
  {
    float3 transformedRayOrigin;
    transformedRayOrigin = 4 * (rayOrigin - bvhArgs->worldMinimum);
    gridDims = short3(bvhArgs->smallVoxelCount);
    
    float tmin = 0;
    float tmax = INFINITY;
    dt = precise::divide(1, rayDirection);
    
    // Perform a ray-box intersection test.
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      float t1 = (0 - transformedRayOrigin[i]) * dt[i];
      float t2 = (float(gridDims[i]) - transformedRayOrigin[i]) * dt[i];
      tmin = max(tmin, min(min(t1, t2), tmax));
      tmax = min(tmax, max(max(t1, t2), tmin));
    }
    
    // Adjust the origin so it starts in the grid.
    // NOTE: This translates `t` by an offset of `tmin`.
    *canIntersectGrid = (tmin < tmax);
    transformedRayOrigin += tmin * rayDirection;
    transformedRayOrigin = max(transformedRayOrigin, float3(0));
    transformedRayOrigin = min(transformedRayOrigin, float3(gridDims));
    this->tmin = tmin * 0.25;
    
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      float origin = transformedRayOrigin[i];
      if (dt[i] < 0) {
        origin = float(gridDims[i]) - origin;
      }
      
      
      // `t` is actually the future `t`. When incrementing each dimension's `t`,
      // which one will produce the smallest `t`? This dimension gets the
      // increment because we want to intersect the closest voxel, which hasn't
      // been tested yet.
      t[i] = (floor(origin) - origin) * abs(dt[i]) + abs(dt[i]);
      maybeInvertedPosition[i] = ushort(origin);
    }
  }
  
  void incrementPosition() {
    ushort2 cond_mask;
    cond_mask[0] = (t.x < t.y) ? 1 : 0;
    cond_mask[1] = (t.x < t.z) ? 1 : 0;
    uint desired = as_type<uint>(ushort2(1, 1));
    
    if (as_type<uint>(cond_mask) == desired) {
      voxel_tmax = t.x; // actually t + dt
      t.x += abs(dt.x); // actually t + dt + dt
      
      maybeInvertedPosition.x += 1;
    } else if (t.y < t.z) {
      voxel_tmax = t.y;
      t.y += abs(dt.y);
      
      maybeInvertedPosition.y += 1;
    } else {
      voxel_tmax = t.z;
      t.z += abs(dt.z);
      
      maybeInvertedPosition.z += 1;
    }
  }
  
  float maximumAcceptedHitTime() const {
    return tmin + voxel_tmax * 0.25;
  }
  
  uint createAddress() const {
    short3 invertedPosition = gridDims - 1 - maybeInvertedPosition;
    short3 actualPosition = select(maybeInvertedPosition,
                                   invertedPosition,
                                   dt < 0);
    return VoxelAddress::generate(ushort3(gridDims),
                                  ushort3(actualPosition));
  }
  
  bool createContinueLoop() const {
    return (maybeInvertedPosition.x < gridDims.x) &&
    (maybeInvertedPosition.y < gridDims.y) &&
    (maybeInvertedPosition.z < gridDims.z);
  }
};

#endif // DDA_H
