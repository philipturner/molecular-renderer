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
    
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      if (dt[i] < 0) {
        float origin = transformedRayOrigin[i];
        originalCorrectPosition[i] = ceil(origin) - 1;
      } else {
        float origin = transformedRayOrigin[i];
        originalCorrectPosition[i] = floor(origin);
      }
      
      if (dt[i] < 0) {
        float origin = transformedRayOrigin[i];
        originalTime[i] = (ceil(origin) - origin) * dt[i];
      } else {
        float origin = transformedRayOrigin[i];
        originalTime[i] = (floor(origin) - origin) * dt[i];
      }
    }
  }
  
  float3 nextTimes(short3 progressCounter) const {
    const float3 currentTimes = originalTime + float3(progressCounter) * dt;
    const float3 nextTimes = currentTimes + abs(dt);
    return nextTimes;
  }
  
  short3 increment(short3 progressCounter) const {
    const float3 nextTimes = this->nextTimes(progressCounter);
    
    short3 output = progressCounter;
    if (nextTimes[0] < nextTimes[1] &&
        nextTimes[0] < nextTimes[2]) {
      output[0] += (dt[0] >= 0) ? 1 : -1;
    } else if (nextTimes[1] < nextTimes[2]) {
      output[1] += (dt[1] >= 0) ? 1 : -1;
    } else {
      output[2] += (dt[2] >= 0) ? 1 : -1;
    }
    return output;
  }
  
  float voxelMaximumHitTime(short3 progressCounter) const {
    const float3 nextTimes = this->nextTimes(progressCounter);
    
    float smallestNextTime;
    if (nextTimes[0] < nextTimes[1] &&
        nextTimes[0] < nextTimes[2]) {
      smallestNextTime = nextTimes[0];
    } else if (nextTimes[1] < nextTimes[2]) {
      smallestNextTime = nextTimes[1];
    } else {
      smallestNextTime = nextTimes[2];
    }
    return minimumTime + smallestNextTime * 0.25;
  }
  
  short3 cellCoordinates(short3 progressCounter, ushort3 gridDims) const {
    return originalCorrectPosition + progressCounter;
  }
  
  bool continueLoop(short3 progressCounter, ushort3 gridDims) const {
    short3 correctPosition = cellCoordinates(progressCounter, gridDims);
    
    return (correctPosition.x >= 0 && correctPosition.x < gridDims.x) &&
    (correctPosition.y >= 0 && correctPosition.y < gridDims.y) &&
    (correctPosition.z >= 0 && correctPosition.z < gridDims.z);
  }
};

#endif // DDA_H
