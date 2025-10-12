func createDDAUtility(worldDimension: Float) -> String {
  func cellBorderArgument() -> String {
    #if os(macOS)
    "thread float3 &cellBorder"
    #else
    "inout float3 cellBorder"
    #endif
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
      // dtdx = 1 / rayDirection;
      // dx =
      // \(Shader.select("float3(-0.25, -0.25, -0.25)", "float3(0.25, 0.25, 0.25)", "dtdx >= 0"))
      // dx = select(half3(-0.25), half3(0.25), dtdx >= 0);
      
      // *cellBorder = rayOrigin;
      // *cellBorder /= 0.25;
      // *cellBorder = select(ceil(*cellBorder), floor(*cellBorder), dtdx >= 0);
      // *cellBorder *= 0.25;
    }
  };
  """
}
