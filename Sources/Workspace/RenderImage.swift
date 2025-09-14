import Foundation // String.init(format:_:)
import HDL

func createRenderImage(atoms: [SIMD4<Float>]) -> String {
  func moleculeCoordinates() -> String {
    func createList() -> String {
      func repr(atom: SIMD4<Float>) -> String {
        let x = String(format: "%.3f", atom[0])
        let y = String(format: "%.3f", atom[1])
        let z = String(format: "%.3f", atom[2])
        return "float3(\(x), \(y), \(z))"
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
    constant float3 moleculeCoordinates[\(atoms.count)] = {
      \(createList())
    };
    """
    #else
    return """
    static const float3 moleculeCoordinates[\(atoms.count)] = {
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
      device half *atomicNumbers [[buffer(1)]],
      constant AtomCountArgs *atomCountArgs [[buffer(2)]],
      uint2 tid [[thread_position_in_grid]])
    """
    #else
    """
    RWTexture2D<float4> frameBuffer : register(u0);
    RWBuffer<float> atomicNumbers : register(u1);
    ConstantBuffer<AtomCountArgs> atomCountArgs : register(b2);
    
    [numthreads(8, 8, 1)]
    [RootSignature(
      "DescriptorTable(UAV(u0, numDescriptors = 1)),"
      "DescriptorTable(UAV(u1, numDescriptors = 1)),"
      "RootConstants(num32BitConstants = 1, b2),"
    )]
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
    "frameBuffer.write(float4(color, 0), tid);"
    #else
    "frameBuffer[tid] = float4(color, 0);"
    #endif
  }
  
  return """
  \(moleculeCoordinates())
  
  \(createAtomColors(AtomStyles.colors))
  \(createAtomRadii(AtomStyles.radii))
  
  // Bypass errors in the HLSL compiler.
  struct AtomCountArgs {
    uint atomCount;
  };
  
  \(functionSignature())
  {
    // Query the screen's dimensions.
    \(queryScreenDimensions())
    if ((tid.x >= screenWidth) ||
        (tid.y >= screenHeight)) {
      return;
    }
    
    // Background color.
    float3 color = float3(0.707, 0.707, 0.707);
    
    // Prepare the screen-space coordinates.
    // [-0.5 nm, 0.5 nm] along the two axes of the screen.
    float2 screenCoords = float2(tid);
    screenCoords /= float2(screenWidth, screenHeight);
    screenCoords -= float2(0.5, 0.5);
    
    // Raster the atoms in order of depth.
    float maximumDepth = -1e38;
    uint32_t hitAtomicNumber = 0;
    for (uint32_t atomID = 0; atomID < \(atoms.count); ++atomID)
    {
      float3 atom = moleculeCoordinates[atomID];
      uint32_t atomicNumber = atomicNumbers[atomID];
      
      // Perform a point-circle intersection test.
      float radius = atomRadii[atomicNumber];
      float2 atomPosition = atom.xy;
      float2 delta = screenCoords - atomPosition;
      float distance = sqrt(dot(delta, delta));
      if (distance > radius) {
        continue;
      }
      float depthCorrection = sqrt(radius * radius - distance * distance);
      
      // The most crude search: a single Z coordinate for the entire atom,
      // just like the impostor method.
      float atomDepth = atom.z;
      atomDepth += depthCorrection;
      if (atomDepth > maximumDepth) {
        maximumDepth = atomDepth;
        hitAtomicNumber = atomicNumber;
      }
    }
    
    // Use the color of the hit atom.
    if (hitAtomicNumber > 0) {
      color = atomColors[hitAtomicNumber];
    }
    
    // Write the pixel to the screen.
    \(writeColor())
  }
  """
}

// Generate the shader code for the atom colors.
private func createAtomColors(_ colors: [SIMD3<Float>]) -> String {
  func createList() -> String {
    func repr(color: SIMD3<Float>) -> String {
      let r = String(format: "%.3f", color[0])
      let g = String(format: "%.3f", color[1])
      let b = String(format: "%.3f", color[2])
      return "float3(\(r), \(g), \(b))"
    }
    
    var output: String = ""
    for color in colors {
      output += repr(color: color)
      output += ",\n"
    }
    return output
  }
  
  #if os(macOS)
  return """
  constant float3 atomColors[\(colors.count)] = {
    \(createList())
  };
  """
  #else
  return """
  static const float3 atomColors[\(colors.count)] = {
    \(createList())
  };
  """
  #endif
}

// Generate the shader code for the atom radii.
private func createAtomRadii(_ radii: [Float]) -> String {
  func createList() -> String {
    var output: String = ""
    for radius in radii {
      output += String(format: "%.3f", radius)
      output += ",\n"
    }
    return output
  }
  
  #if os(macOS)
  return """
  constant float atomRadii[\(radii.count)] = {
    \(createList())
  };
  """
  #else
  return """
  static const float atomRadii[\(radii.count)] = {
    \(createList())
  };
  """
  #endif
}
