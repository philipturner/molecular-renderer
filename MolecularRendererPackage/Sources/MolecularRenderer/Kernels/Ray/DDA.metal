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
  // The passed-in ray origin.
  float3 rayOrigin;
  
  // Inverse of ray direction.
  float3 dtdx;
  
  // How much to move when switching to a new cell.
  half3 dx;
  
public:
  DDA(float3 rayOrigin, float3 rayDirection, thread float3 *progressCounter) {
    this->rayOrigin = rayOrigin;
    
    dtdx = precise::divide(1, rayDirection);
    dx = select(half3(-0.25), half3(0.25), dtdx >= 0);
    
    *progressCounter = rayOrigin;
    *progressCounter /= 0.25;
    *progressCounter = select(ceil(*progressCounter),
                              floor(*progressCounter),
                              dtdx >= 0);
    *progressCounter *= 0.25;
  }
  
  float3 nextTimes(float3 progressCounter) const {
    float3 nextCounter = progressCounter + float3(dx);
    return (nextCounter - rayOrigin) * dtdx;
  }
  
  float3 increment(float3 progressCounter) const {
    const float3 nextTimes = this->nextTimes(progressCounter);
    
    float3 output = progressCounter;
    if (nextTimes[0] < nextTimes[1] &&
        nextTimes[0] < nextTimes[2]) {
      output[0] += dx[0];
    } else if (nextTimes[1] < nextTimes[2]) {
      output[1] += dx[1];
    } else {
      output[2] += dx[2];
    }
    return output;
  }
  
  float voxelMaximumHitTime(float3 progressCounter) const {
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
  
  short3 cellCoordinates(float3 progressCounter, ushort3 gridDims) const {
    float3 output = 256 + (progressCounter) * 4;
    output += select(float3(-1), float3(0), dtdx >= 0);
    return short3(output);
  }
  
  bool continueLoop(float3 progressCounter, ushort3 gridDims) const {
    short3 correctPosition = cellCoordinates(progressCounter, gridDims);
    
    return (correctPosition.x >= 0 && correctPosition.x < gridDims.x) &&
    (correctPosition.y >= 0 && correctPosition.y < gridDims.y) &&
    (correctPosition.z >= 0 && correctPosition.z < gridDims.z);
  }
};

#endif // DDA_H
