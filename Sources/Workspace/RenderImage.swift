func createRenderImage() -> String {
  func functionSignature() -> String {
    #if os(macOS)
    """
    #include <metal_stdlib>
    using namespace metal;
    
    kernel void renderImage(
      texture2d<float, access::write> frameBuffer [[texture(0)]],
      uint2 tid [[thread_position_in_grid]])
    """
    #else
    """
    RWTexture2D<float4> frameBuffer : register(u0);
    
    [numthreads(8, 8, 1)]
    [RootSignature(
      "DescriptorTable(UAV(u0, numDescriptors = 1))")]
    void renderImage(
      uint2 tid : SV_DispatchThreadID)
    """
    #endif
  }
  
  func queryScreenDimensions() -> String {
    #if os(macOS)
    """
    uint screenWidth = frameBuffer.get_width();
    uint screenHeight = frameBuffer.get_height();
    """
    #else
    """
    uint screenWidth;
    uint screenHeight;
    frameBuffer.GetDimensions(screenWidth, screenHeight);
    """
    #endif
  }
  
  func writeColor() -> String {
    #if os(macOS)
    "frameBuffer.write(color, tid);"
    #else
    "frameBuffer[tid] = color;"
    #endif
  }
  
  return """
  \(functionSignature())
  {
    // Query the screen's dimensions.
    \(queryScreenDimensions())
    if ((tid.x >= screenWidth) ||
        (tid.y >= screenHeight)) {
      return;
    }
    
    // Render something based on the pixel's position.
    float4 color = float4(0.707, 0.707, 0.707, 0.000);
    
    {
      float2 normalizedPosition = float2(tid);
      normalizedPosition /= float2(screenWidth, screenHeight);
      
      float2 center = float2(0.5, 0.5);
      float2 delta = normalizedPosition - center;
      float distance = sqrt(dot(delta, delta));
      
      if (distance < 0.1) {
        color = float4(0.500, 0.500, 0.500, 0.000);
      }
    }
    
    // Write the pixel to the screen.
    \(writeColor())
  }
  """
}
