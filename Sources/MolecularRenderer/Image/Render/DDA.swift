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
  // - https://ieeexplosre.ieee.org/document/7349894
  struct DDA {
    // Inverse of ray direction.
    float3 dtdx;
    
    // How much to move when switching to a new cell.
    float3 dx;
    
    // Cell spacing is 0.25 nm.
    void initialize(\(cellBorderArgument()),
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
  };
  """
}
