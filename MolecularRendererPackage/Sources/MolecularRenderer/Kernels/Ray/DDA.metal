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
  // - TODO: Can we also store the increment explicitly, in floating point?
  float3 dt;
  
  // Always negative, unless ray origin falls on a cell border (then zero).
  float3 originalTime;
  
  // Cell where the origin lies.
  // - TODO: Can this be converted to floating point?
  short3 originalCorrectPosition;
  
public:
  DDA(float3 rayOrigin, float3 rayDirection) {
    dt = precise::divide(1, rayDirection);
    dt *= 0.25;
    
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      float origin = rayOrigin[i] / 0.25;
      float roundedOrigin;
      if (dt[i] < 0) {
        roundedOrigin = ceil(origin);
      } else {
        roundedOrigin = floor(origin);
      }
      
      originalCorrectPosition[i] = short(roundedOrigin);
      originalCorrectPosition[i] += (dt[i] >= 0) ? 0 : -1;
      originalTime[i] = (roundedOrigin - origin) * dt[i];
    }
  }
  
  float3 nextTimes(short3 progressCounter) const {
    float3 output = originalTime;
    output += float3(progressCounter) * dt;
    
    float3 increment = select(float3(-1), float3(1), dt >= 0);
    output += increment * dt;
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
    return 256 + originalCorrectPosition + progressCounter;
  }
  
  bool continueLoop(short3 progressCounter, ushort3 gridDims) const {
    short3 correctPosition = cellCoordinates(progressCounter, gridDims);
    
    return (correctPosition.x >= 0 && correctPosition.x < gridDims.x) &&
    (correctPosition.y >= 0 && correctPosition.y < gridDims.y) &&
    (correctPosition.z >= 0 && correctPosition.z < gridDims.z);
  }
};

#endif // DDA_H
