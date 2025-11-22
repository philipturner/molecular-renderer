// Fallback for debugging if the upscaler goes wrong, or for easily
// visualizing the 3 inputs to the upscaler.
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
    
    // Utility for visualizing grayscale quantities
    // with more distinction between very close numbers.
    //
    // n = 0: red
    // n = 8: green
    // n = 4: blue
    float convertToChannel(
      float hue,
      float saturation,
      float lightness,
      uint n
    ) {
      float k = float(n) + hue / 30;
      k -= 12 * floor(k / 12);
      
      float a = saturation;
      a *= min(lightness, 1 - lightness);
      
      float output = min(k - 3, 9 - k);
      output = max(output, float(-1));
      output = min(output, float(1));
      output = lightness - a * output;
      return output;
    }
    
    \(functionSignature())
    {
      // Read from the input texture.
      uint2 inputCoords = pixelCoords / \(Int(upscaleFactor));
      \(readColor())
      
      // Write to the output texture.
      \(writeColor())
    }
    """
  }
}