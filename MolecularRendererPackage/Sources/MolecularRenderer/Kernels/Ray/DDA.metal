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
  float3 originalTime;
  float3 progressedTime;
  
  // Progress of the adjusted ray w.r.t. the original ray. This ensures closest
  // hits are recognized in the correct order.
  float minimumTime; // in the original coordinate space
  float voxelMaximumTime; // in the relative coordinate space
  
public:
  short3 gridDims;
  short3 originalMaybeInvertedPosition;
  short3 progressedMaybeInvertedPosition;
  
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
    minimumTime = tmin * 0.25;
    
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
      originalTime[i] = (floor(origin) - origin) * abs(dt[i]) + abs(dt[i]);
      progressedTime[i] = float(0);
      
      originalMaybeInvertedPosition[i] = short(ushort(origin));
      progressedMaybeInvertedPosition[i] = short(0);
    }
  }
  
  void updateVoxelMaximumTime() {
    const float3 currentTime = createCurrentTime();
    
    if (currentTime.x < currentTime.y &&
        currentTime.x < currentTime.z) {
      voxelMaximumTime = currentTime.x;
    } else if (currentTime.y < currentTime.z) {
      voxelMaximumTime = currentTime.y;
    } else {
      voxelMaximumTime = currentTime.z;
    }
  }
  
  void incrementPosition() {
    const float3 currentTime = createCurrentTime();
    
    if (currentTime.x < currentTime.y &&
        currentTime.x < currentTime.z) {
      progressedTime.x += abs(dt.x);
      progressedMaybeInvertedPosition.x += 1;
    } else if (currentTime.y < currentTime.z) {
      progressedTime.y += abs(dt.y);
      progressedMaybeInvertedPosition.y += 1;
    } else {
      progressedTime.z += abs(dt.z);
      progressedMaybeInvertedPosition.z += 1;
    }
  }
  
  float3 createCurrentTime() const {
    return originalTime + progressedTime;
  }
  
  float createMaximumAcceptedHitTime() const {
    return minimumTime + voxelMaximumTime * 0.25;
  }
  
  short3 createMaybeInvertedPosition() const {
    return originalMaybeInvertedPosition + progressedMaybeInvertedPosition;
  }
  
  uint createAddress() const {
    short3 maybeInvertedPosition = createMaybeInvertedPosition();
    short3 invertedPosition = gridDims - 1 - maybeInvertedPosition;
    short3 actualPosition = select(maybeInvertedPosition,
                                   invertedPosition,
                                   dt < 0);
    return VoxelAddress::generate(ushort3(gridDims),
                                  ushort3(actualPosition));
  }
  
  bool createContinueLoop() const {
    short3 maybeInvertedPosition = createMaybeInvertedPosition();
    return (maybeInvertedPosition.x < gridDims.x) &&
    (maybeInvertedPosition.y < gridDims.y) &&
    (maybeInvertedPosition.z < gridDims.z);
  }
};

#endif // DDA_H
