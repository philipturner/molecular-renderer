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
  // Inverse of ray direction.
  float3 dt;
  
  // Always positive, unless ray origin falls within the domain (then zero).
  float minimumTime;
  
  // Always negative, unless ray origin falls on a cell border (then zero).
  float3 originalTime;
  
  // Cell where the origin lies, but properly handling negative directions and
  // border cases.
  // - What are all of the possible edge cases?
  short3 originalCorrectPosition;
  
public:
  DDA(float3 rayOrigin,
      float3 rayDirection,
      constant BVHArguments *bvhArgs,
      thread bool *returnEarly)
  {
    // TODO: -
    // - Is it possible to change the 'gridDims' variable to represent the
    //   actual coordinates in nanometers? If not, why? Point to the specific
    //   line of code that prevents this change from taking place.
    float3 transformedRayOrigin;
    transformedRayOrigin = 4 * (rayOrigin - bvhArgs->worldMinimum);
    float3 gridDims = float3(bvhArgs->smallVoxelCount);
    
    float tmin = 0;
    float tmax = INFINITY;
    dt = precise::divide(1, rayDirection);
    dt *= 0.25;
    
    // Perform a ray-box intersection test.
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      // Here
      float t1 = (0 - transformedRayOrigin[i]) * dt[i];
      
      // Here
      float t2 = (gridDims[i] - transformedRayOrigin[i]) * dt[i];
      tmin = max(tmin, min(min(t1, t2), tmax));
      tmax = min(tmax, max(max(t1, t2), tmin));
    }
    minimumTime = tmin * 0.25;
    *returnEarly = (tmax <= 0);
    
    // Adjust the origin so it starts in the grid.
    transformedRayOrigin += tmin * rayDirection;
    
    // Here
    transformedRayOrigin = max(transformedRayOrigin, float3(0));
    
    // Here
    transformedRayOrigin = min(transformedRayOrigin, gridDims);
    
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      if (dt[i] < 0) {
        // Here
        float origin = transformedRayOrigin[i];
        originalCorrectPosition[i] = ceil(origin) - 1;
      } else {
        // Here
        float origin = transformedRayOrigin[i];
        originalCorrectPosition[i] = floor(origin);
      }
      
      if (dt[i] < 0) {
        // Here
        float origin = transformedRayOrigin[i];
        originalTime[i] = (ceil(origin) - origin) * dt[i];
      } else {
        // Here
        float origin = transformedRayOrigin[i];
        originalTime[i] = (floor(origin) - origin) * dt[i];
      }
    }
  }
  
  float3 nextTimes(short3 progressCounter) const {
    float3 output = float3(minimumTime);
    output += originalTime;
    output += float3(progressCounter) * dt;
    output += abs(dt);
    return output;
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
    return smallestNextTime;
  }
  
  short3 cellCoordinates(short3 progressCounter, ushort3 gridDims) const {
    // Here
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
