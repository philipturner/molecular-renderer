import Foundation // String.init(format:_:)
import HDL

func createRenderImage(atoms: [SIMD4<Float>]) -> String {
  func moleculeCoordinates() -> String {
    func createList() -> String {
      func repr(atom: SIMD4<Float>) -> String {
        let x = String(format: "%.3f", atom[0])
        let y = String(format: "%.3f", atom[1])
        let z = String(format: "%.3f", atom[2])
        let w = String(format: "%.3f", atom[3])
        return "float4(\(x), \(y), \(z), \(w))"
      }
      
      var output: String = ""
      for atom in atoms {
        output += repr(atom: atom)
        output += ",\n"
      }
      return output
    }
    
    #if os(macOS)
    return """
    constant float4 moleculeCoordinates[\(atoms.count)] = {
      \(createList())
    };
    """
    #else
    return """
    static const float4 moleculeCoordinates[\(atoms.count)] = {
      \(createList())
    };
    """
    #endif
  }
  
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
  
  // H: (0.780, 0.780, 0.780), 0.0930 nm
  // C: (0.388, 0.388, 0.388), 0.1426 nm
  // O: (0.502, 0.000, 0.000), 0.1349 nm
  
  return """
  \(moleculeCoordinates())
  
  \(functionSignature())
  {
    // Query the screen's dimensions.
    \(queryScreenDimensions())
    if ((tid.x >= screenWidth) ||
        (tid.y >= screenHeight)) {
      return;
    }
    
    // Background color.
    float4 color = float4(0.707, 0.707, 0.707, 0.000);
    
    // Prepare the screen-space coordinates.
    // [-0.5 nm, 0.5 nm] along the two axes of the screen.
    float2 screenCoords = float2(tid);
    screenCoords /= float2(screenWidth, screenHeight);
    screenCoords -= float2(0.5, 0.5);
    
    // Raster the atoms in order of depth.
    float maximumDepth = -1e38;
    for (int16_t atomID = 0; atomID < \(atoms.count); ++atomID)
    {
      // TODO
    }
    
    // Write the pixel to the screen.
    \(writeColor())
  }
  """
}
