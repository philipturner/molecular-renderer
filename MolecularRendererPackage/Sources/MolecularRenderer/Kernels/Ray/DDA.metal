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
  float3 dtdx;
  
  // How much to move when switching to a new cell.
  half3 dx;
  
  // Cell where the origin lies.
  float3 roundedOrigin;
  
  // Always negative, unless ray origin falls on a cell border (then zero).
  float3 originalTime;
  
public:
  DDA(float3 rayOrigin, float3 rayDirection) {
    dtdx = precise::divide(1, rayDirection);
    dx = select(half3(-0.25), half3(0.25), dtdx >= 0);
    
    roundedOrigin = rayOrigin;
    roundedOrigin /= 0.25;
    roundedOrigin = select(ceil(roundedOrigin),
                           floor(roundedOrigin),
                           dtdx >= 0);
    roundedOrigin *= 0.25;
    
    // TODO: Change this, so the rounded origin is re-factored in every time
    // the next time is requested. The ray's passed-in origin should be the
    // only thing held in registers.
    originalTime = (roundedOrigin - rayOrigin) * dtdx;
  }
  
  // TODO: Change the counter to nanometers.
  float3 nextTimes(float3 progressCounter) const {
    float3 output = originalTime;
    output += progressCounter * dtdx;
    output += float3(dx) * dtdx;
    return output;
  }
  
  // TODO: Change the counter to nanometers.
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
  
  // TODO: Change the counter to nanometers.
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
  
  // TODO: Change the counter to nanometers.
  short3 cellCoordinates(float3 progressCounter, ushort3 gridDims) const {
    // Here
    float3 output = 256 + (roundedOrigin + progressCounter) * 4;
    output += select(float3(-1), float3(0), dtdx >= 0);
    return short3(output);
  }
  
  // TODO: Change the counter to nanometers.
  bool continueLoop(float3 progressCounter, ushort3 gridDims) const {
    short3 correctPosition = cellCoordinates(progressCounter, gridDims);
    
    return (correctPosition.x >= 0 && correctPosition.x < gridDims.x) &&
    (correctPosition.y >= 0 && correctPosition.y < gridDims.y) &&
    (correctPosition.z >= 0 && correctPosition.z < gridDims.z);
  }
};

#endif // DDA_H
