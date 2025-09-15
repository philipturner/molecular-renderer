import Foundation // String.init(format:_:)

public struct RenderImage {
  public static func createSource() -> String {
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
      kernel void renderImage(
        texture2d<float, access::write> frameBuffer [[texture(0)]],
        device float4 *atoms [[buffer(1)]],
        constant ConstantArgs &constantArgs [[buffer(2)]],
        uint2 tid [[thread_position_in_grid]])
      """
      #else
      """
      RWTexture2D<float4> frameBuffer : register(u0);
      RWStructuredBuffer<float4> atoms : register(u1);
      ConstantBuffer<ConstantArgs> constantArgs : register(b2);
      
      [numthreads(8, 8, 1)]
      [RootSignature(
        "DescriptorTable(UAV(u0, numDescriptors = 1)),"
        "UAV(u1),"
        "RootConstants(b2, num32BitConstants = 2),"
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
    \(importStandardLibrary())
    
    \(createAtomColors(AtomStyles.colors))
    \(createAtomRadii(AtomStyles.radii))
    \(createIntersectUtility())
    \(createLightingUtility())
    
    // TODO: Migrate this import to the internals of the ray gen utility.
    \(createSamplingUtility())
    
    struct ConstantArgs {
      uint atomCount;
      uint frameSeed;
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
      
      // Prepare the intersection query.
      // origin:
      //   XY = screen coords
      //   Z = +10 nm
      // direction:
      //   XY = 0.00
      //   Z = -1.00
      IntersectionQuery query;
      query.rayOrigin = float3(screenCoords, 10);
      query.rayDirection = float3(0, 0, -1);
      
      // Prepare the intersection result.
      IntersectionResult intersect;
      intersect.accept = false;
      intersect.distance = 1e38;
      
      // Test every atom.
      for (uint atomID = 0; atomID < constantArgs.atomCount; ++atomID)
      {
        float4 atom = atoms[atomID];
        intersectAtom(intersect,
                      query,
                      atom,
                      atomID);
      }
      
      // Check whether we found a hit.
      if (intersect.distance < 1e38) {
        intersect.accept = true;
      }
      
      // Use the color of the hit atom.
      if (intersect.accept) {
        // Compute the hit point.
        float4 hitAtom = atoms[intersect.atomID];
        float3 hitPoint = query.rayOrigin;
        hitPoint += intersect.distance * query.rayDirection;
        float3 hitNormal = normalize(hitPoint - hitAtom.xyz);
        
        // Prepare the ambient occlusion.
        AmbientOcclusion ambientOcclusion;
        ambientOcclusion.diffuseAtomicNumber = uint(hitAtom[3]);
        ambientOcclusion.diffuseAccumulator = 0;
        ambientOcclusion.specularAccumulator = 0;
        
        // Prepare the Blinn-Phong lighting.
        BlinnPhongLighting blinnPhong;
        blinnPhong.lambertianAccumulator = 0;
        blinnPhong.specularAccumulator = 0;
        
        // Apply the camera position.
        blinnPhong.addLightContribution(hitPoint,
                                        hitNormal,
                                        query.rayOrigin);
        color = blinnPhong.createColor(ambientOcclusion);
      }
      
      // Write the pixel to the screen.
      \(writeColor())
    }
    """
  }
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
