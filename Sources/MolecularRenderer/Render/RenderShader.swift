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
      func optionalFunctionArguments() -> String {
        guard upscaleFactor > 1 else {
          return ""
        }
        
        #if os(macOS)
        return """
        texture2d<float, access::write> depthTexture [[texture(\(Self.depthTexture))]],
        texture2d<float, access::write> motionTexture [[texture(\(Self.motionTexture))]],
        """
        #else
        return """
        RWTexture2D<float4> depthTexture : register(u\(Self.depthTexture));
        RWTexture2D<float4> motionTexture : register(u\(Self.motionTexture));
        """
        #endif
      }
      
      #if os(Windows)
      func optionalRootSignatureArguments() -> String {
        guard upscaleFactor > 1 else {
          return ""
        }
        
        return """
        "DescriptorTable(UAV(u\(Self.depthTexture), numDescriptors = 1)),"
        "DescriptorTable(UAV(u\(Self.motionTexture), numDescriptors = 1)),"
        """
      }
      #endif
      
      #if os(macOS)
      return """
      kernel void render(
        constant ConstantArgs &constantArgs [[buffer(\(Self.constantArgs))]],
        constant CameraArgsList &cameraArgs [[buffer(\(Self.cameraArgs))]],
        device float4 *atoms [[buffer(\(Self.atoms))]],
        texture2d<float, access::write> colorTexture [[texture(\(Self.colorTexture))]],
        \(optionalFunctionArguments())
        uint2 pixelCoords [[thread_position_in_grid]])
      """
      #else
      let byteCount = MemoryLayout<ConstantArgs>.size
      
      return """
      ConstantBuffer<ConstantArgs> constantArgs : register(b\(Self.constantArgs));
      ConstantBuffer<CameraArgsList> cameraArgs : register(b\(Self.cameraArgs));
      RWStructuredBuffer<float4> atoms : register(u\(Self.atoms));
      RWTexture2D<float4> colorTexture : register(u\(Self.colorTexture));
      \(optionalFunctionArguments())
      
      [numthreads(8, 8, 1)]
      [RootSignature(
        "RootConstants(b\(Self.constantArgs), num32BitConstants = \(byteCount / 4)),"
        "CBV(b\(Self.cameraArgs)),"
        "UAV(u\(Self.atoms)),"
        "DescriptorTable(UAV(u\(Self.colorTexture), numDescriptors = 1)),"
        \(optionalRootSignatureArguments())
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
    
    func write(
      _ value: String,
      texture: String
    ) -> String {
      #if os(macOS)
      "\(texture).write(\(value), pixelCoords);"
      #else
      "\(texture)[pixelCoords] = \(value);"
      #endif
    }
    
    func computeDepth() -> String {
      guard upscaleFactor > 1 else {
        return ""
      }
      
      return """
      {
        float3 rayDirection = primaryRayDirection;
        float3 cameraDirection = cameraArgs.data[0].basis.col2;
        float rayDirectionComponent = dot(rayDirection, cameraDirection);
        float depth = rayDirectionComponent * intersect.distance;
        
        // Map the depth from [0, -infinity] to [1, 0].
        depth = 1 / (1 - depth);
        \(write("depth", texture: "depthTexture"))
      }
      """
    }
    
    func computeMotionVector() -> String {
      guard upscaleFactor > 1 else {
        return ""
      }
      
      return """
      if (intersect.accept) {
        // Intersection of jittered ray (pixelCoords are jittered).
        float3 currentHitPoint = query.rayOrigin;
        currentHitPoint += intersect.distance * query.rayDirection;
        
        // Not yet implemented atom motion vector tracking.
        float3 atomMotionVector = 0;
        float3 previousHitPoint = currentHitPoint + atomMotionVector;
        
        // Invert mapping: ray intersection -> primary ray direction
        float3 cameraPosition = cameraArgs.data[1].position;
        float3 rayDirection = previousHitPoint - cameraPosition;
        rayDirection = normalize(rayDirection);
        
        // Undo camera basis mapping.
        Matrix3x3 cameraBasis = cameraArgs.data[1].basis;
        rayDirection = cameraBasis.transpose().multiply(rayDirection);
        
        // Invert operation: normalize(rayDirection)
        rayDirection *= -1 / rayDirection.z;
        
        // Invert the preparation of screen-space coordinates.
        float2 screenCoords = rayDirection.xy;
        screenCoords /= cameraArgs.data[1].tangentFactor;
        screenCoords.y = -screenCoords.y;
        screenCoords.x *= float(screenDimensions.y) / float(screenDimensions.x);
        screenCoords = (screenCoords + 1) / 2;
        
        // Important: dynamic resolution not allowed.
        float2 previousPixelCoords = screenCoords * float2(screenDimensions);
        
        // Compare against current coordinates.
        float2 jitterOffset = 0;
        float2 currentPixelCoords = float2(pixelCoords) + 0.5;
        currentPixelCoords += jitterOffset;
        
        // FidelityFX docs: encode motion from current frame to previous frame
        float2 motionVector = previousPixelCoords - currentPixelCoords;
        
        // Guarantee this doesn't cause issues from exceeding the dynamic
        // range of FP16.
        motionVector = clamp(motionVector, float(-65000), float(65000));
        \(write("float4(motionVector, 0, 0)", texture: "motionTexture"))
      } else {
        float2 motionVector = 0;
        \(write("float4(motionVector, 0, 0)", texture: "motionTexture"))
      }
      """
    }
    
    return """
    \(importStandardLibrary())
    
    \(createAtomColors(AtomStyles.colors))
    \(createAtomRadii(AtomStyles.radii))
    \(createLightingUtility())
    \(createRayGeneration())
    \(createRayIntersector())
    
    \(ConstantArgs.shaderDeclaration)
    \(CameraArgs.shaderDeclaration)
    struct CameraArgsList {
      CameraArgs data[2];
    };
    
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
                                         cameraArgs.data[0].tangentFactor,
                                         cameraArgs.data[0].basis);
      
      // Intersect the primary ray.
      IntersectionQuery query;
      query.rayOrigin = cameraArgs.data[0].position;
      query.rayDirection = primaryRayDirection;
      IntersectionResult intersect = rayIntersector.intersect(query);
      
      // Write the depth and motion vector ASAP, reducing register pressure.
      \(computeDepth())
      \(computeMotionVector())
      
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
      \(write("float4(color, 0)", texture: "colorTexture"))
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
