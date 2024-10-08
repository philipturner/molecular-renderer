//
//  DDA.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/4/23.
//

#ifndef DDA_H
#define DDA_H

#include <metal_stdlib>
#include "../Utilities/Arguments.metal"
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
  
  // Cell spacing is 0.25 nm.
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
  
  // Cell spacing is 2.00 nm.
  //
  // Clamps to a bounding box measured in 8 nm voxels, starting at the
  // lower corner of (-128, -128, -128) nm.
  DDA(thread float3 *cellBorder,
      float3 rayOrigin,
      float3 rayDirection,
      float3 boxMinimum,
      float3 boxMaximum) {
    dtdx = precise::divide(1, rayDirection);
    dx = select(half3(-2.00), half3(2.00), dtdx >= 0);
    
    float minimumTime = float(1e38);
#pragma clang loop unroll(full)
    for (ushort i = 0; i < 3; ++i) {
      float t1 = (boxMinimum[i] - rayOrigin[i]) * dtdx[i];
      float t2 = (boxMaximum[i] - rayOrigin[i]) * dtdx[i];
      float tmin = min(t1, t2);
      minimumTime = min(tmin, minimumTime);
    }
    minimumTime = max(minimumTime, float(0));
    
    float3 origin = rayOrigin + minimumTime * rayDirection;
    origin = max(origin, boxMinimum);
    origin = min(origin, boxMaximum);
    
    *cellBorder = origin;
    *cellBorder /= 2.00;
    *cellBorder = select(ceil(*cellBorder), floor(*cellBorder), dtdx >= 0);
    *cellBorder *= 2.00;
  }
  
  float3 cellLowerCorner(float3 cellBorder) const {
    float3 output = cellBorder;
    output += select(float3(dx), float3(0), dtdx >= 0);
    return output;
  }
  
  float3 nextTimes(float3 cellBorder, float3 rayOrigin) const {
    float3 nextBorder = cellBorder + float3(dx);
    float3 nextTimes = (nextBorder - rayOrigin) * dtdx;
    return nextTimes;
  }
  
  float3 nextBorder(float3 cellBorder, float3 nextTimes) const {
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
  
  float voxelMaximumHitTime(float3 cellBorder, float3 nextTimes) const {
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
  
  // Only call this when the cell spacing is 2.0 nm.
  float3 nextCellGroup(float3 flippedCellBorder,
                       float3 flippedRayOrigin,
                       float3 flippedRayDirection) const {
    // Round current coordinates down to 8.0 nm.
    float3 nextBorder = flippedCellBorder;
    nextBorder /= 8;
    nextBorder = floor(nextBorder);
    nextBorder = nextBorder * 8;
    
    // Add 8.0 nm to each.
    nextBorder += 8;
    
    // Pick the axis with the smallest time.
    ushort axisID;
    float t;
    {
      // Find the time for each.
      float3 nextTimes = (nextBorder - flippedRayOrigin) * abs(dtdx);
      
      // Branch on which axis won.
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
    }
    
    // Make speculative next positions.
    float3 output = flippedRayOrigin + t * flippedRayDirection;
    output /= 2;
    output = floor(output);
    output *= 2;
    
    // Guarantee forward progress.
#pragma clang loop unroll(full)
    for (ushort i = 0; i < 3; ++i) {
      if (i == axisID) {
        output[i] = nextBorder[i];
      }
      output[i] = max(output[i], flippedCellBorder[i]);
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
  // - 961 instructions / 3.926 billion issued
  // - 958 instructions / 3.882 billion issued
  // - 955 instructions / 3.829 billion issued
  // - 955 instructions / 3.825 billion issued
  //
  // - 946 instructions / 4.057 billion issued
  // - 949 instructions / 4.116 billion issued
  // - 948 instructions / 4.039 billion issued
  // - 948 instructions / 4.046 billion issued
  // - 942 instructions / 3.984 billion issued
  // - 942 instructions / 3.961 billion issued
  // - 942 instructions / 3.957 billion issued
  // - 942 instructions / 3.991 billion issued
  // - 936 instructions / 4.048 billion issued
  //
  // - 4.1 ms
  // - per-line statistics:
  //   - 70% ALU time
  //   - 20% control flow time
  //   - 37.86% primary ray
  //   - 50.80% secondary rays
  // - overall shader statistics:
  //   - 936 instructions
  //   - 4.054 billion instructions issued
  //   - 27.95% divergence
  //
  // Memory tape, divergent (1).
  // - 3.7 ms
  // - per-line statistics:
  //   - 75% ALU time
  //   - 20% control flow time
  //   - 37.28% primary ray
  //   - 50.78% secondary rays
  // - overall shader statistics:
  //   - 937 instructions
  //   - 4.052 billion instructions issued
  //   - 27.87% divergence
  //
  // Memory tape, divergent (2).
  // - 4.0 ms
  // - per-line statistics:
  //   - 37.76% primary ray
  //   - 50.57% secondary rays
  // - overall shader statistics:
  //   - 940 instructions
  //   - 4.093 billion instructions issued
  //   - 27.69% divergence
  //
  // Memory tape, convergent.
  // - 3.8 ms
  // - per-line statistics:
  //   - 38.97% primary ray
  //   - 49.67% secondary rays
  // - overall shader statistics:
  //   - 946 instructions
  //   - 4.155 billion instructions issued
  //   - 27.96% divergence
  //
  // Before expanding the world volume (128 nm).
  // - 3.6 ms
  // - per-line statistics:
  //   - 39.37% primary ray
  //   - 49.06% secondary rays
  // - overall shader statistics:
  //   - 945 instructions
  //   - 4.096 billion instructions issued
  //   - 27.94% divergence
  //
  // Expanding the world volume to 256 nm.
  // - 4.1 ms
  // - per-line statistics:
  //   - 48.70% primary ray
  //   - 41.52% secondary rays
  // - overall shader statistics:
  //   - 945 instructions
  //   - 5.032 billion instructions issued
  //   - 24.84% divergence
  //
  // 948 instructions / 4.926 billion issued
  // 949 instructions / 4.929 billion issued
  // 950 instructions / 4.800 billion issued
  // 946 instructions / 4.665 billion issued
  // 945 instructions / 4.562 billion issued
  // 948 instructions / 4.497 billion issued
  // 960 instructions / 4.506 billion issued
  // 959 instructions / 4.411 billion issued
  // 957 instructions / 4.350 billion issued
  //
  // Optimizing the primary ray's DDA over 2 nm cells.
  // - 4.7 ms
  // - per-line statistics:
  //   - 44.54% primary ray
  //   - 44.83% secondary rays
  // - overall shader statistics:
  //   - 957 instructions
  //   - 4.350 billion issued
  //   - 30.06% divergence
  //
  // Expanding the world volume to 512 nm.
  // - 5.1 ms
  // - per-line statistics:
  //   - 55.90% primary ray
  //   - 35.25% secondary rays
  // - overall shader statistics:
  //   - 957 instructions
  //   - 5.578 billion instructions issued
  //   - 27.87% divergence
  //
  // Reverting to 128 nm.
  // - 3.1 ms
  // - per-line statistics:
  //   - 36.09% primary ray
  //   - 51.67% secondary rays
  // - overall shader statistics:
  //   - 956 instructions
  //   - 3.723 billion instructions issued
  //   - 31.49% divergence
  //
  // Undoing some optimizations to primary rays.
  // - 3.9 ms
  // - per-line statistics:
  //   - 39.37% primary ray
  //   - 49.46% secondary rays
  // - overall shader statistics:
  //   - 944 instructions
  //   - 4.077 billion instructions issued
  //   - 29.03% divergence
  //
  // Reducing the memory consumption of large cell metadata.
  // - 39.04% / 49.31%
  // - 946 instructions
  // - 4.078 billion instructions issued
  //
  // - 38.71% / 49.45%
  // - 946 instructions
  // - 4.080 billion instructions issued
  //
  // - 39.20% / 49.28%
  // - 946 instructions
  // - 4.072 billion instructions issued
  //
  // Finalizing the world volume at 256 nm.
  // - 4.3 ms
  // - per-line statistics:
  //   - 48.62% primary ray
  //   - 41.28% secondary rays
  // - overall shader statistics:
  //   - 946 instructions
  //   - 4.994 billion instructions issued
  //   - 26.48% divergence
  //
  // After skipping ahead at the granularity of 4 large cells.
  // - 3.5 ms
  // - per-line statistics:
  //   - 36.92% primary ray
  //   - 51.07% secondary rays
  // - overall shader statistics:
  //   - 1046 instructions
  //   - 4.244 billion instructions issued
  //   - 26.25% divergence
  //
  // After optimizing the instruction count.
  // 35.82% / 52.13%, 1028 / 4.107 billion issued
  // 36.43% / 51.80%, 1026 / 4.082 billion issued
  // 34.92% / 52.87%, 1016 / 3.901 billion issued
  // 35.04% / 52.32%, 1017 / 3.832 billion issued
  // 34.62% / 52.64%, 1017 / 3.836 billion issued
  // 34.77% / 52.99%, 1015 / 3.821 billion issued
  // - 3.3 ms
  // - per-line statistics:
  //   - 34.87% primary ray
  //   - 52.63% secondary rays
  // - overall shader statistics:
  //   - 1017 instructions
  //   - 3.833 billion instructions issued
  //   - 28.63%
  //
  // After using a global bounding box.
  // - 2.9 ms
  // - per-line statistics:
  //   - 26.21% primary ray
  //   - 60.29% secondary rays
  // - overall shader statistics:
  //   - 1049 instructions
  //   - 3.230 billion issued
  //   - 32.78% divergence
};

#endif // DDA_H
