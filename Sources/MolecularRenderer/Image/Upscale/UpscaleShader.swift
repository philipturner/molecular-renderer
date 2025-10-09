// Fallback for debugging if the upscaler goes wrong, or for easily
// visualizing the 3 inputs to the upscaler.
struct UpscaleShader {
  static func createSource(upscaleFactor: Float) -> String {
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
    \(Shader.importStandardLibrary)
    
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
