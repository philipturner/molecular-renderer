// Placeholder until each platform has the actual upscaler implemented.
struct UpscaleShader {
  static func createSource(upscaleFactor: Float) -> String {
    func importStandardLibrary() -> String {
      #if os(macOS)
      """
      #include <metal_stdlib>
      using namespace metal;
      """
      #else
      ""
      #endif
    }
    
    func functionSignature() -> String {
      #if os(macOS)
      """
      kernel void upscale(
        texture2d<float, access::read> colorTexture [[texture(0)]],
        texture2d<float, access::write> upscaledTexture [[texture(1)]],
        uint2 pixelCoords [[thread_position_in_grid]])
      """
      #else
      """
      RWTexture2D<float4> colorTexture : register(u0);
      RWTexture2D<float4> upscaledTexture : register(u1);
      
      [numthreads(8, 8, 1)]
      [RootSignature(
        "DescriptorTable(UAV(u0, numDescriptors = 1)),"
        "DescriptorTable(UAV(u1, numDescriptors = 1)),"
      )]
      void upscale(
        uint2 pixelCoords : SV_DispatchThreadID)
      """
      #endif
    }
    
    func readColor() -> String {
      #if os(macOS)
      "float4 color = colorTexture.read(inputCoords);"
      #else
      "float4 color = colorTexture[inputCoords];"
      #endif
    }
    
    func writeColor() -> String {
      #if os(macOS)
      "upscaledTexture.write(color, pixelCoords);"
      #else
      "upscaledTexture[pixelCoords] = color;"
      #endif
    }
    
    return """
    \(importStandardLibrary())
    
    \(functionSignature())
    {
      // Read from the input texture.
      uint2 inputCoords = pixelCoords / \(Int(upscaleFactor));
      \(readColor())
      
      // Divide per-pixel coordinates to a range that fits within viewable color.
      color = color / 5;
      
      // Red = X motion, green = Y motion
      // Motion with the wrong sign should be clamped to 0 (black).
      color = saturate(color);
      
      // Write to the output texture.
      \(writeColor())
    }
    """
  }
}
