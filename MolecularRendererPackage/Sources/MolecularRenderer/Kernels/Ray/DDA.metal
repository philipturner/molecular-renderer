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
  
public:
  DDA(thread float3 *cellBorder,
      float3 rayOrigin,
      float3 rayDirection) {
    dtdx = precise::divide(1, rayDirection);
    dx = select(half3(-0.25), half3(0.25), dtdx >= 0);
    
    *cellBorder = rayOrigin;
    *cellBorder /= 0.25;
    *cellBorder = select(ceil(*cellBorder), floor(*cellBorder), dtdx >= 0);
    *cellBorder *= 0.25;
  }
  
  float3 cellLowerCorner(float3 cellBorder) const {
    float3 output = cellBorder;
    output += select(float3(dx), float3(0), dtdx >= 0);
    return output;
  }
  
  float voxelMaximumHitTime(float3 cellBorder, float3 rayOrigin) const {
    float3 nextBorder = cellBorder + float3(dx);
    float3 nextTimes = (nextBorder - rayOrigin) * dtdx;
    
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
  
  float3 nextSmallBorder(float3 cellBorder, float3 rayOrigin) const {
    float3 nextBorder = cellBorder + float3(dx);
    float3 nextTimes = (nextBorder - rayOrigin) * dtdx;
    
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
  
  float3 nextLargeBorder(float3 cellBorder, 
                         float3 rayOrigin,
                         float3 rayDirection) const {
    float3 roundedUpBorder;
    ushort axisID;
    float t;
    {
      // Round current coordinates down to 2.0 nm.
      float3 nextBorder = cellBorder;
      nextBorder /= 2.00;
      nextBorder = select(ceil(nextBorder), floor(nextBorder), dtdx >= 0);
      nextBorder *= 2.00;
      
      // Add 2.0 nm to each.
      nextBorder += 8 * float3(dx);
      
      // Find the time for each.
      float3 nextTimes = (nextBorder - rayOrigin) * dtdx;
      
      // Pick the axis with the smallest time.
      if (nextTimes[0] < nextTimes[1] &&
          nextTimes[0] < nextTimes[2]) {
        axisID = 0;
        t = nextTimes[0];
      } else if (nextTimes[1] < nextTimes[2]) {
        axisID = 1;
        t = nextTimes[1];
      } else {
        axisID = 2;
        t = nextTimes[2];
      }
      
      // Save the 'nextBorder' variable with a different name.
      roundedUpBorder = nextBorder;
    }
    
    // Make speculative next positions.
    float3 nextBorder = rayOrigin + t * rayDirection;
    nextBorder /= 0.25;
    nextBorder = select(ceil(nextBorder), floor(nextBorder), dtdx >= 0);
    nextBorder *= 0.25;
    
    // Guarantee forward progress.
    float3 nextSmallBorder = this->nextSmallBorder(cellBorder, rayOrigin);
#pragma clang loop unroll(full)
    for (ushort i = 0; i < 3; ++i) {
      if (i == axisID) {
        
      } else {
        
      }
      
      if (dtdx[i] >= 0) {
        nextBorder[i] = max(nextBorder[i], nextSmallBorder[i]);
      } else {
        nextBorder[i] = min(nextBorder[i], nextSmallBorder[i]);
      }
    }
    nextBorder = nextSmallBorder;
    
    // Start by taking the maximum of the value here, and the next small-cell
    // border. In theory, the large jump should include every small jump in
    // between.
    //
    // Before implementing fast forward:
    // - 7.5 ms at low clock speed
    // - 2.7 ms at high clock speed
    return nextBorder;
  }
};

#endif // DDA_H
