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
  float minimumTime;
  float3 originalTime;
  short3 originalCorrectPosition;
  
public:
  DDA(float3 rayOrigin,
      float3 rayDirection,
      constant BVHArguments *bvhArgs,
      thread bool *returnEarly)
  {
    float3 transformedRayOrigin;
    transformedRayOrigin = 4 * (rayOrigin - bvhArgs->worldMinimum);
    ushort3 gridDims = bvhArgs->smallVoxelCount;
    
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
    minimumTime = tmin * 0.25;
    *returnEarly = (tmin >= tmax);
    
    // Adjust the origin so it starts in the grid.
    // NOTE: This translates `t` by an offset of `tmin`.
    transformedRayOrigin += tmin * rayDirection;
    transformedRayOrigin = max(transformedRayOrigin, float3(0));
    transformedRayOrigin = min(transformedRayOrigin, float3(gridDims));
    
    short3 originalMaybeInvertedPosition;
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
      originalTime[i] = (floor(origin) - origin) * abs(dt[i]);
      originalMaybeInvertedPosition[i] = short(ushort(origin));
    }
    
    {
      short3 invertedPosition = short3(gridDims) - 1 - originalMaybeInvertedPosition;
      originalCorrectPosition = select(originalMaybeInvertedPosition,
                                              invertedPosition,
                                              dt < 0);
    }
  }
  
  ushort3 increment(ushort3 progressCounter) const {
    const float3 currentTime = this->currentTime(progressCounter);
    
    ushort3 output = progressCounter;
    if (currentTime.x < currentTime.y &&
        currentTime.x < currentTime.z) {
      output[0] += 1;
    } else if (currentTime.y < currentTime.z) {
      output[1] += 1;
    } else {
      output[2] += 1;
    }
    return output;
  }
  
  float voxelMaximumTime(ushort3 progressCounter) const {
    const float3 currentTime = this->currentTime(progressCounter);
    
    if (currentTime.x < currentTime.y &&
        currentTime.x < currentTime.z) {
      return currentTime.x;
    } else if (currentTime.y < currentTime.z) {
      return currentTime.y;
    } else {
      return currentTime.z;
    }
  }
  
  float maximumHitTime(float voxelMaximumTime) const {
    return minimumTime + voxelMaximumTime * 0.25;
  }
  
  float3 currentTime(ushort3 progressCounter) const {
    return originalTime + float3(progressCounter + 1) * abs(dt);
  }
  
  short3 maybeInvertedPosition(ushort3 progressCounter, ushort3 gridDims) const {
    short3 invertedPosition = short3(gridDims) - 1 - originalCorrectPosition;
    short3 maybeInvertedPosition2 = select(originalCorrectPosition, invertedPosition, dt < 0);
    return maybeInvertedPosition2 + short3(progressCounter);
  }
  
  bool continueLoop(ushort3 progressCounter, ushort3 gridDims) const {
    short3 maybeInvertedPosition = this->maybeInvertedPosition(progressCounter, gridDims);
    short3 correctPosition = short3(cellCoordinates(progressCounter, gridDims));
    
    short3 invertedPosition = short3(gridDims) - 1 - correctPosition;
    short3 maybeInvertedPosition2 = select(correctPosition, invertedPosition, dt < 0);
    
//    return (correctPosition.x >= 0 && correctPosition.x < gridDims.x) &&
//    (correctPosition.y >= 0 && correctPosition.y < gridDims.y) &&
//    (correctPosition.z >= 0 && correctPosition.z < gridDims.z);
    return (maybeInvertedPosition2.x < gridDims.x) &&
    (maybeInvertedPosition2.y < gridDims.y) &&
    (maybeInvertedPosition2.z < gridDims.z);
  }
  
  ushort3 cellCoordinates(ushort3 progressCounter, ushort3 gridDims) const {
    short3 maybeInvertedPosition = this->maybeInvertedPosition(progressCounter, gridDims);
    short3 invertedPosition = short3(gridDims) - 1 - maybeInvertedPosition;
    short3 actualPosition = select(maybeInvertedPosition,
                                   invertedPosition,
                                   dt < 0);
    return ushort3(actualPosition);
  }
};

#endif // DDA_H
