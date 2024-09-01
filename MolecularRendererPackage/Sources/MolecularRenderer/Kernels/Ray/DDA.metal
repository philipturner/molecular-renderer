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
  float minimumTime;
  
public:
  short3 gridDims;
  short3 originalMaybeInvertedPosition;
  
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
      
      originalMaybeInvertedPosition[i] = short(ushort(origin));
    }
  }
  
  void updateVoxelMaximumTime(thread float *voxelMaximumTime,
                              ushort3 progressCounter) const {
    const float3 currentTime = createCurrentTime(progressCounter);
    
    if (currentTime.x < currentTime.y &&
        currentTime.x < currentTime.z) {
      *voxelMaximumTime = currentTime.x;
    } else if (currentTime.y < currentTime.z) {
      *voxelMaximumTime = currentTime.y;
    } else {
      *voxelMaximumTime = currentTime.z;
    }
  }
  
  void incrementProgressCounter(thread ushort3 *progressCounter) const {
    const float3 currentTime = createCurrentTime(*progressCounter);
    
    if (currentTime.x < currentTime.y &&
        currentTime.x < currentTime.z) {
      progressCounter->x += 1;
    } else if (currentTime.y < currentTime.z) {
      progressCounter->y += 1;
    } else {
      progressCounter->z += 1;
    }
  }
  
  float3 reconstructProgressedTime(ushort3 progressCounter) const {
    return float3(progressCounter) * abs(dt);
  }
  
  short3 reconstructProgressedMaybeInvertedPosition(ushort3 progressCounter) const {
    return short3(progressCounter);
  }
  
  float3 createCurrentTime(ushort3 progressCounter) const {
    return originalTime + reconstructProgressedTime(progressCounter);
  }
  
  float createMaximumAcceptedHitTime(float voxelMaximumTime) const {
    return minimumTime + voxelMaximumTime * 0.25;
  }
  
  short3 createMaybeInvertedPosition(ushort3 progressCounter) const {
    return originalMaybeInvertedPosition + reconstructProgressedMaybeInvertedPosition(progressCounter);
  }
  
  uint createAddress(ushort3 progressCounter) const {
    short3 maybeInvertedPosition = createMaybeInvertedPosition(progressCounter);
    short3 invertedPosition = gridDims - 1 - maybeInvertedPosition;
    short3 actualPosition = select(maybeInvertedPosition,
                                   invertedPosition,
                                   dt < 0);
    return VoxelAddress::generate(ushort3(gridDims),
                                  ushort3(actualPosition));
  }
  
  bool createContinueLoop(ushort3 progressCounter) const {
    short3 maybeInvertedPosition = createMaybeInvertedPosition(progressCounter);
    return (maybeInvertedPosition.x < gridDims.x) &&
    (maybeInvertedPosition.y < gridDims.y) &&
    (maybeInvertedPosition.z < gridDims.z);
  }
};

#endif // DDA_H
