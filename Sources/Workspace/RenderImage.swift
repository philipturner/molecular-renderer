import HDL

func createRenderImage() -> String {
  func moleculeCoordinates() -> String {
    func createAtoms() -> [SIMD4<Float>] {
      return [
        Atom(position: SIMD3( 2.0186, -0.2175,  0.7985) * 0.1, element: .hydrogen),
        Atom(position: SIMD3( 1.4201, -0.2502, -0.1210) * 0.1, element: .carbon),
        Atom(position: SIMD3( 1.6783,  0.6389, -0.7114) * 0.1, element: .hydrogen),
        Atom(position: SIMD3( 1.7345, -1.1325, -0.6927) * 0.1, element: .hydrogen),
        Atom(position: SIMD3(-0.0726, -0.3145,  0.1833) * 0.1, element: .carbon),
        Atom(position: SIMD3(-0.2926, -1.2317,  0.7838) * 0.1, element: .hydrogen),
        Atom(position: SIMD3(-0.3758,  0.8195,  0.9774) * 0.1, element: .oxygen),
        Atom(position: SIMD3(-1.3159,  0.8236,  1.0972) * 0.1, element: .hydrogen),
        Atom(position: SIMD3(-0.8901, -0.3435, -1.1071) * 0.1, element: .carbon),
        Atom(position: SIMD3(-0.7278,  0.5578, -1.7131) * 0.1, element: .hydrogen),
        Atom(position: SIMD3(-0.6126, -1.2088, -1.7220) * 0.1, element: .hydrogen),
        Atom(position: SIMD3(-1.9673, -0.4150, -0.9062) * 0.1, element: .hydrogen),
      ]
    }
    
    func repr(atom: SIMD4<Float>) -> String {
      let x = String(format: "%.3f", atom[0])
      let y = String(format: "%.3f", atom[1])
      let z = String(format: "%.3f", atom[2])
      let w = String(format: "%.3f", atom[3])
      return "float4(\(x), \(y), \(z), \(w))"
    }
    
    func createList(atoms: [SIMD4<Float>]) -> String {
      var output: String = ""
      for atom in atoms
    }
    
    return ""
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
  
  return """
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
    
    // Render a CO molecule.
    float bondLength = 0.1128;
    float2 normalizedPosition = float2(tid);
    normalizedPosition /= float2(screenWidth, screenHeight);
    
    if (normalizedPosition.x < 0.51) {
      float2 center = float2(0.5 - bondLength / 2, 0.5);
      float2 delta = normalizedPosition - center;
      float distance = sqrt(dot(delta, delta));
      
      // Render the carbon atom.
      if (distance < 0.1426) {
        color = float4(0.388, 0.388, 0.388, 0.000);
      }
    } else {
      float2 center = float2(0.5 + bondLength / 2, 0.5);
      float2 delta = normalizedPosition - center;
      float distance = sqrt(dot(delta, delta));
      
      // Render the oxygen atom.
      if (distance < 0.1349) {
        color = float4(0.502, 0.000, 0.000, 0.000);
      }
    }
    
    // Write the pixel to the screen.
    \(writeColor())
  }
  """
}
