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
struct DDA {
  // Inverse of ray direction.
  float3 dtdx;
  
  // How much to move when switching to a new cell.
  half3 dx;
  
  DDA() {
    dtdx = float3(0);
    dx = half3(0);
  }
  
  DDA(thread float3 *cellBorder,
      float3 rayOrigin,
      float3 rayDirection,
      float cellSpacing) {
    dtdx = precise::divide(1, rayDirection);
    dx = select(half3(-cellSpacing), half3(cellSpacing), dtdx >= 0);
    
    *cellBorder = rayOrigin;
    *cellBorder /= cellSpacing;
    *cellBorder = select(ceil(*cellBorder), floor(*cellBorder), dtdx >= 0);
    *cellBorder *= cellSpacing;
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
  
  // Before implementing fast forward:
  // - 7.5 ms at low clock speed
  // - 2.7 ms at high clock speed
  //
  // After implementing fast forward:
  // - 3.8 ms
  // - per-line statistics:
  //   - 70% ALU time
  //   - 25% control flow time
  // - overall shader statistics:
  //   - 993 instructions
  //   - 5.127 billion instructions issued
  //   - 28.42% divergence
  //
  // Deferring atom testing to after the next cursor increment:
  // - 4.4 ms
  // - per-line statistics:
  //   - 67% ALU time
  //   - 28% control flow time
  // - overall shader statistics:
  //   - 1117 instructions
  //   - 6.040 billion instructions issued
  //   - 30.08% divergence
  //
  // Compressing cell border and using thread index to gate the cell search
  // under a runtime conditional:
  // - 4.8 ms
  // - per-line statistics:
  //  - 65% ALU time
  //  - 35% control flow time
  //  - 30.98% primary ray
  //  - 50.63% secondary rays
  // - overall shader statistics:
  //  - 1181 instructions
  //  - 6.314 billion instructions issued
  //  - 29.22% divergence
  //
  // Implementing a full inner 'while' loop.
  // - 5.8 ms
  // - per-line statistics:
  //   - 65% ALU time
  //   - 35% control flow time
  //   - 27.20% primary ray
  //   - 65.99% secondary rays
  // - overall shader statistics:
  //   - 1150 instructions
  //   - 7.638 billion instructions issued
  //   - 42.81% divergence
  //
  // Only doing 'while' loop for primary rays.
  // - 4.2 ms
  // - per-line statistics:
  //   - 70% ALU time
  //   - 25% control flow time
  //   - 33.98% primary ray
  //   - 57.20% secondary rays
  // - overall shader statistics:
  //   - 1133 instructions
  //   - 5.863 billion instructions issued
  //   - 31.44% divergence
  //
  // Not skipping large voxels for secondary rays.
  // - 4.6 ms
  // - per-line statistics:
  //   - 70% ALU time
  //   - 25% control flow time
  //   - 33.72% primary ray
  //   - 58.24% secondary rays
  // - overall shader statistics:
  //   - 1054 instructions
  //   - 5.563 billion instructions issued
  //   - 26.56% divergence
  //
  // Not skipping large voxels for primary rays.
  // - 9.5 ms
  // - per-line statistics:
  //   - 80% ALU time
  //   - 15% control flow time
  //   - 67.98% primary ray
  //   - 28.13% secondary rays
  // - overall shader statistics:
  //   - 973 instructions
  //   - 12.039 billion instructions issued
  //   - 20.56% divergence
  //
  // Removing skip-forward for AO rays.
  // - 4.2 ms
  // - per-line statistics:
  //   - 70% ALU time
  //   - 25% control flow time
  //   - 36.45% primary ray
  //   - 53.62% secondary rays
  // - overall shader statistics:
  //   - 986 instructions
  //   - 5.098 billion instructions issued
  //   - 24.37% divergence
  //
  // Simplifying control flow for AO rays (option 1).
  // - 4.5 ms
  // - per-line statistics:
  //   - 75% ALU time
  //   - 20% control flow time
  //   - 36.71% primary ray
  //   - 52.86% secondary rays
  // - overall shader statistics:
  //   - 998 instructions
  //   - 5.081 billion instructions issued
  //   - 25.38% divergence
  //
  // Simplifying control flow for AO rays (option 2).
  // - 4.4 ms
  // - per-line statistics:
  //   - 75% ALU time
  //   - 20% control flow time
  //   - 37.64% primary ray
  //   - 51.45% secondary rays
  // - overall shader statistics:
  //   - 989 instructions
  //   - 4.964 billion instructions issued
  //   - 24.33% divergence
  //
  // Simplifying control flow for AO rays (option 3).
  // - 4.4 ms
  // - per-line statistics:
  //   - 75% ALU time
  //   - 20% control flow time
  //   - 37.57% primary ray
  //   - 51.72% secondary rays
  // - overall shader statistics:
  //   - 989 instructions
  //   - 4.946 billion instructions issued
  //   - 24.13% divergence
  //
  // Making the accepted border code go through registers.
  // - 4.1 ms
  // - per-line statistics:
  //   - 75% ALU time
  //   - 20% control flow time
  //   - 37.65% primary ray
  //   - 52.38% secondary rays
  // - overall shader statistics:
  //   - 979 instructions
  //   - 4.947 billion instructions issued
  //   - 23.88% divergence
  //
  // Changing the codec for the border code.
  // - 4.4 ms
  // - per-line statistics:
  //   - 75% ALU time
  //   - 20% control flow time
  //   - 36.49% primary ray
  //   - 53.69% secondary rays
  // - overall shader statistics:
  //   - 970 instructions
  //   - 4.880 billion instructions issued
  //   - 24.02% divergence
  //
  // Storing all of the intersected voxels in advance.
  // - 4.2 ms
  // - per-line statistics:
  //   - 70% ALU time
  //   - 25% control flow time
  //   - 39.16% primary ray
  //   - 50.69% secondary rays
  // - overall shader statistics:
  //   - 992 instructions
  //   - 5.018 billion instructions issued
  //   - 22.34% divergence
  //
  // Initial speculative searching.
  // - 4.9 ms
  // - per-line statistics:
  //   - 75% ALU time
  //   - 15% control flow time
  //   - 43.08% primary ray
  //   - 46.21% secondary rays
  // - overall shader statistics:
  //   - 1062 instructions
  //   - 6.133 billion instructions issued
  //   - 18.36% divergence
  //
  // Reducing the instruction count a little bit.
  // - 4.2 ms
  // - per-line statistics:
  //   - 75% ALU time
  //   - 20% control flow time
  //   - 41.46% primary ray
  //   - 47.01% secondary rays
  // - overall shader statistics:
  //   - 1005 instructions
  //   - 4.599 billion instructions issued
  //   - 23.84% divergence
  //
  // Restructuring the loop to reduce divergence.
  // - 4.8 ms
  // - per-line statistics:
  //   - 75% ALU time
  //   - 15% control flow time
  //   - 43.52% primary ray
  //   - 45.26% secondary rays
  // - overall shader statistics:
  //   - 1024 instructions
  //   - 4.743 billion instructions issued
  //   - 24.41% divergence
  //
  // Pre-computing the small DDA's minimum time.
  // - 4.4 ms
  // - per-line statistics:
  //   - 70% ALU time
  //   - 25% control flow time
  //   - 37.88% primary ray
  //   - 51.08% secondary rays
  // - overall shader statistics:
  //   - 1005 instructions
  //   - 4.067 billion instructions issued
  //   - 26.82% divergence
  //
  // Merging the large lower corner with the ray's origin.
  // - 3.8 ms
  // - per-line statistics:
  //   - 70% ALU time
  //   - 25% control flow time
  //   - 38.29% primary ray
  //   - 50.76% secondary rays
  // - overall shader statistics:
  //   - 993 instructions
  //   - 4.005 billion instructions issued
  //   - 26.73% divergence
  //
  // Remaining optimizations to instruction count.
  //
  // Attempting to reduce load imbalance of divergent halting.
};

#endif // DDA_H
