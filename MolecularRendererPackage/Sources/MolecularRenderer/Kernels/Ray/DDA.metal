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
  
  // TODO: Remove the ray origin from the DDA's instance members. Enter it as
  // a function argument during every property access.
  
  // TODO: Remove the 'continueLoop' member. Instead, implement the logic in
  // calling code. This may be important for detecting transitions between
  // large cells.
  
  DDA(float3 rayOrigin, float3 rayDirection, thread float3 *cellBorder) {
    this->rayOrigin = rayOrigin;
    
    dtdx = precise::divide(1, rayDirection);
    dx = select(half3(-0.25), half3(0.25), dtdx >= 0);
    
    *cellBorder = rayOrigin;
    *cellBorder /= 0.25;
    *cellBorder = select(ceil(*cellBorder), floor(*cellBorder), dtdx >= 0);
    *cellBorder *= 0.25;
  }
  
  float3 nextTimes(float3 cellBorder) const {
    float3 nextBorder = cellBorder + float3(dx);
    return (nextBorder - rayOrigin) * dtdx;
  }
  
  float3 increment(float3 cellBorder) const {
    const float3 nextTimes = this->nextTimes(cellBorder);
    
    float3 output = cellBorder;
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
  
  float voxelMaximumHitTime(float3 cellBorder) const {
    const float3 nextTimes = this->nextTimes(cellBorder);
    
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
  
  short3 cellCoordinates(float3 cellBorder) const {
    float3 output = 256 + (cellBorder) * 4;
    output += select(float3(-1), float3(0), dtdx >= 0);
    return short3(output);
  }
  
  bool continueLoop(float3 cellBorder, ushort3 gridDims) const {
    short3 correctPosition = cellCoordinates(cellBorder);
    
    return (correctPosition.x >= 0 && correctPosition.x < gridDims.x) &&
    (correctPosition.y >= 0 && correctPosition.y < gridDims.y) &&
    (correctPosition.z >= 0 && correctPosition.z < gridDims.z);
  }
};

#endif // DDA_H
