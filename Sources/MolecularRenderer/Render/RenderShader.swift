import Foundation // String.init(format:_:)

struct RenderShader {
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
      return """
      kernel void render(
        constant ConstantArgs &constantArgs [[buffer(0)]],
        device float4 *atoms [[buffer(1)]],
        texture2d<float, access::write> colorTexture [[texture(2)]],
        uint2 pixelCoords [[thread_position_in_grid]])
      """
      #else
      let byteCount = MemoryLayout<ConstantArgs>.size
      
      return """
      ConstantBuffer<ConstantArgs> constantArgs : register(b0);
      RWStructuredBuffer<float4> atoms : register(u1);
      RWTexture2D<float4> colorTexture : register(u2);
      
      [numthreads(8, 8, 1)]
      [RootSignature(
        "RootConstants(b0, num32BitConstants = \(byteCount / 4)),"
        "UAV(u1),"
        "DescriptorTable(UAV(u2, numDescriptors = 1)),"
      )]
      void render(
        uint2 pixelCoords : SV_DispatchThreadID)
      """
      #endif
    }
    
    func queryScreenDimensions() -> String {
      #if os(macOS)
      """
      uint2 screenDimensions(colorTexture.get_width(),
                             colorTexture.get_height());
      """
      #else
      """
      uint2 screenDimensions;
      colorTexture.GetDimensions(screenDimensions.x,
                                 screenDimensions.y);
      """
      #endif
    }
    
    func writeColor() -> String {
      #if os(macOS)
      "colorTexture.write(float4(color, 0), pixelCoords);"
      #else
      "colorTexture[pixelCoords] = float4(color, 0);"
      #endif
    }
    
    return """
    \(importStandardLibrary())
    
    \(createAtomColors(AtomStyles.colors))
    \(createAtomRadii(AtomStyles.radii))
    \(createLightingUtility())
    \(createRayGeneration())
    \(createRayIntersector())
    
    \(ConstantArgs.shaderDeclaration)
    
    \(functionSignature())
    {
      // Query the screen's dimensions.
      \(queryScreenDimensions())
      if ((pixelCoords.x >= screenDimensions.x) ||
          (pixelCoords.y >= screenDimensions.y)) {
        return;
      }
      
      // Prepare the ray intersector.
      RayIntersector rayIntersector;
      rayIntersector.atoms = atoms;
      rayIntersector.atomCount = constantArgs.atomCount;
      
      // Prepare the ray direction.
      float3 primaryRayDirection =
      RayGeneration::primaryRayDirection(pixelCoords,
                                         screenDimensions,
                                         constantArgs.tangentFactor,
                                         constantArgs.cameraBasis);
      
      // Intersect the primary ray.
      IntersectionQuery query;
      query.rayOrigin = constantArgs.cameraPosition;
      query.rayDirection = primaryRayDirection;
      IntersectionResult intersect = rayIntersector.intersect(query);
      
      // Background color.
      float3 color = float3(0.707, 0.707, 0.707);
      
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
        
        // Pick the number of AO samples.
        uint sampleCount = 7;
        
        // Create a generation context.
        GenerationContext generationContext;
        generationContext.seed = RayGeneration::createSeed(
          pixelCoords, constantArgs.frameSeed);
        
        // Iterate over the AO samples.
        for (uint i = 0; i < sampleCount; ++i) {
          // Spawn a secondary ray.
          float3 secondaryRayOrigin = hitPoint + 1e-4 * float3(hitNormal);
          float3 secondaryRayDirection = generationContext
            .secondaryRayDirection(i, sampleCount, hitPoint, hitNormal);
          
          // Intersect the secondary ray.
          IntersectionQuery query;
          query.rayOrigin = secondaryRayOrigin;
          query.rayDirection = secondaryRayDirection;
          IntersectionResult intersect = rayIntersector.intersect(query);
          
          // Add the secondary ray's AO contributions.
          uint atomicNumber;
          if (intersect.accept) {
            float4 atom = atoms[intersect.atomID];
            atomicNumber = uint(atom[3]);
          } else {
            atomicNumber = 0;
          }
          ambientOcclusion.addAmbientContribution(
            atomicNumber, intersect.distance);
        }
        
        // Tell the context how many AO samples were taken.
        ambientOcclusion.finishAmbientContributions(sampleCount);
        
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
