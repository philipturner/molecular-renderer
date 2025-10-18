func createDDAUtility(worldDimension: Float) -> String {
  func cellBorderArgument() -> String {
    #if os(macOS)
    "thread float3 &cellBorder"
    #else
    "inout float3 cellBorder"
    #endif
  }
  
  func float3(_ repeatedValue: Float) -> String {
    "float3(\(repeatedValue), \(repeatedValue), \(repeatedValue))"
  }
  
  return """
  // Source:
  // - https://tavianator.com/2022/ray_box_boundary.html
  // - https://ieeexplore.ieee.org/document/7349894
  struct DDA {
    // Inverse of ray direction.
    float3 dtdx;
    
    // How much to move when switching to a new cell.
    float3 dx;
    
    // Cell spacing: 0.25 nm
    void initializeSmall(\(cellBorderArgument()),
                         float3 rayOrigin,
                         float3 rayDirection)
    {
      dtdx = 1 / rayDirection;
      dx = \(Shader.select(float3(-0.25), float3(0.25), "dtdx >= 0"));
      
      cellBorder = rayOrigin;
      cellBorder /= 0.25;
      cellBorder =
      \(Shader.select("ceil(cellBorder)", "floor(cellBorder)", "dtdx >= 0"));
      cellBorder *= 0.25;
    }
    
    // Cell spacing: 2 nm
    void initializeLarge(\(cellBorderArgument()),
                         float3 rayOrigin,
                         float3 rayDirection)
    {
      dtdx = 1 / rayDirection;
      dx = \(Shader.select(float3(-2), float3(2), "dtdx >= 0"));
      
      float minimumTime = 1e38;
      \(Shader.unroll)
      for (uint i = 0; i < 3; ++i) {
        float t1 = (\(-worldDimension / 2) - rayOrigin[i]) * dtdx[i];
        float t2 = (\(worldDimension / 2) - rayOrigin[i]) * dtdx[i];
        float tmin = min(t1, t2);
        minimumTime = min(tmin, minimumTime);
      }
      minimumTime = max(minimumTime, float(0));
      
      float3 origin = rayOrigin + minimumTime * rayDirection;
      origin = max(origin, \(float3(-worldDimension / 2)));
      origin = min(origin, \(float3(worldDimension / 2)));
      
      cellBorder = origin;
      cellBorder /= 2;
      cellBorder =
      \(Shader.select("ceil(cellBorder)", "floor(cellBorder)", "dtdx >= 0"));
      cellBorder *= 2;
    }
    
    float3 cellLowerCorner(float3 cellBorder) {
      float3 output = cellBorder;
      output += \(Shader.select("dx", float3(0), "dtdx >= 0"));
      return output;
    }
    
    float3 nextTimes(float3 cellBorder, float3 rayOrigin) {
      float3 nextBorder = cellBorder + dx;
      float3 nextTimes = (nextBorder - rayOrigin) * dtdx;
      return nextTimes;
    }
    
    float3 nextBorder(float3 cellBorder, float3 nextTimes) {
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
    
    float voxelMaximumHitTime(float3 cellBorder, float3 nextTimes) {
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
    
    // Cell spacing: 2 nm
    float3 nextCellGroup(float3 flippedCellBorder,
                         float3 flippedRayOrigin,
                         float3 flippedRayDirection,
                         float groupSpacing) {
      // Round current coordinates down to the group spacing.
      float3 nextBorder = flippedCellBorder;
      nextBorder /= groupSpacing;
      nextBorder = floor(nextBorder);
      nextBorder = nextBorder * groupSpacing;
      
      // Add the group spacing to each.
      nextBorder += groupSpacing;
      
      // Pick the axis with the smallest time.
      uint axisID;
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
      \(Shader.unroll)
      for (uint i = 0; i < 3; ++i) {
        if (i == axisID) {
          output[i] = nextBorder[i];
        }
        output[i] = max(output[i], flippedCellBorder[i]);
      }
      
      return output;
    }
  };
  """
}
