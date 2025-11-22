struct RenderShaderDescriptor {
  var isOffline: Bool?
  var memorySlotCount: Int?
  var supports16BitTypes: Bool?
  var upscaleFactor: Float?
  var worldDimension: Float?
}

struct RenderShader {
  // [numthreads(8, 8, 1)]
  // dispatch threads SIMD3(colorTexture.width, colorTexture.height, 1)
  // threadgroup memory 4096 B
  static func createSource(
    descriptor: RenderShaderDescriptor
  ) -> String {
    guard let isOffline = descriptor.isOffline,
          let memorySlotCount = descriptor.memorySlotCount,
          let upscaleFactor = descriptor.upscaleFactor,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    func allocateTapeWindows() -> String {
      #if os(macOS)
      ""
      #else
      "groupshared uint2 memoryTape[8 * 64];"
      #endif
    }
    
    func allocateTapeMac() -> String {
      #if os(macOS)
      "threadgroup uint2 memoryTape[8 * 64];"
      #else
      ""
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
    
    func writeColor() -> String {
      if !isOffline {
        return write("float4(color, 0)", texture: "colorTexture")
      } else {
        func castHalf4(_ input: String) -> String {
          #if os(macOS)
          "half4(\(input))"
          #else
          input
          #endif
        }
        
        return """
        uint pixelAddress = pixelCoords.x;
        pixelAddress += pixelCoords.y * renderArgs.screenDimensions.x;
        colorBuffer[pixelAddress] = \(castHalf4("float4(color, 0)"));
        """
      }
    }
    
    func bindMemoryTape() -> String {
      #if os(macOS)
      "rayIntersector.memoryTape = memoryTape;"
      #else
      ""
      #endif
    }
    
    func computeDepth() -> String {
      guard upscaleFactor > 1 else {
        return ""
      }
      
      func depthTransform() -> String {
        #if os(macOS)
        """
        // Map the depth from [0, -infinity] to [1, 0].
        // Loss of precision close to the near plane, compared to FidelityFX.
        depth = 1 / (1 - depth);
        """
        #else
        """
        // Map the depth from [-0.075, -7.5e36] to [1, 1e-38].
        // FidelityFX internally reprojects this to [0.075, 7.5e36].
        depth = 0.075 / (-depth);
        depth = saturate(depth);
        """
        #endif
      }
      
      return """
      {
        float3 rayDirection = primaryRayDirection;
        float3 cameraDirection = cameraArgs.data[0].basis.col2;
        float rayDirectionComponent = dot(rayDirection, cameraDirection);
        float depth = rayDirectionComponent * intersect.distance;
        if (!intersect.accept) {
          // Fits within the depth range dictated by the camera near plane
          // on Windows + FidelityFX.
          depth = -1e34;
        }
        
        \(depthTransform())
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
        
        float3 atomMotionVector = float4(motionVectors[intersect.atomID]).xyz;
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
        screenCoords.x *= float(renderArgs.screenDimensions.y);
        screenCoords.x /= float(renderArgs.screenDimensions.x);
        screenCoords = (screenCoords + 1) / 2;
        float2 previousPixelCoords = screenCoords;
        previousPixelCoords *= float2(renderArgs.screenDimensions);
        
        // Compare against current coordinates.
        float2 currentPixelCoords = float2(pixelCoords) + 0.5;
        currentPixelCoords += renderArgs.jitterOffset;
        
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
    
    func atomicNumber(_ input: String) -> String {
      "\(Shader.asuint)(\(input)) & 0xFF"
    }

    func rayIntersector() -> String {
      createRayIntersector(
        memorySlotCount: memorySlotCount,
        worldDimension: worldDimension)
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(allocateTapeWindows())
    
    \(AtomStyles.createAtomColors(AtomStyles.colors))
    \(createMatrixUtility())
    \(createRayGeneration())
    \(rayIntersector())
    \(createLightingUtility())
    
    \(RenderArgs.shaderDeclaration)
    \(CameraArgs.shaderDeclaration)
    struct CameraArgsList {
      CameraArgs data[2];
    };
    
    \(Self.functionSignature(descriptor: descriptor))
    {
      \(allocateTapeMac())
      
      if ((pixelCoords.x >= renderArgs.screenDimensions.x) ||
          (pixelCoords.y >= renderArgs.screenDimensions.y)) {
        return;
      }
      
      if (crashBuffer[0] != 1) {
        float3 color = 0;
        \(writeColor())
        return;
      }
      
      // Prepare the ray intersector.
      RayIntersector rayIntersector;
      rayIntersector.atoms = atoms;
      rayIntersector.voxelGroup8OccupiedMarks = voxelGroup8OccupiedMarks;
      rayIntersector.voxelGroup32OccupiedMarks = voxelGroup32OccupiedMarks;
      rayIntersector.assignedSlotIDs = assignedSlotIDs;
      rayIntersector.headers = headers;
      rayIntersector.references32 = references32;
      rayIntersector.references16 = references16;
      \(bindMemoryTape())
      rayIntersector.localID = localID.y * 8 + localID.x;
      
      // Prepare the ray direction.
      float dzdt;
      float3 primaryRayDirection =
      RayGeneration::primaryRayDirection(dzdt,
                                         pixelCoords,
                                         renderArgs.screenDimensions,
                                         renderArgs.jitterOffset,
                                         cameraArgs.data[0].tangentFactor,
                                         cameraArgs.data[0].basis);
      
      // Intersect the primary ray.
      IntersectionQuery query;
      query.rayOrigin = cameraArgs.data[0].position;
      query.rayDirection = primaryRayDirection;
      IntersectionResult intersect = rayIntersector.intersectPrimary(query);
      
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
        ambientOcclusion.diffuseAtomicNumber = \(atomicNumber("hitAtom[3]"));
        ambientOcclusion.diffuseAccumulator = 0;
        ambientOcclusion.specularAccumulator = 0;
        
        // Pick the number of AO samples.
        if (renderArgs.secondaryRayCount > 0) {
          float sampleCount = renderArgs.secondaryRayCount;
          
          // Apply the critical pixel count heuristic.
          if (renderArgs.criticalPixelCount > 0) {
            float pixelCount = 2 * sqrt(hitAtom[3]);
            pixelCount /= (-dzdt * intersect.distance);
            pixelCount *= float(renderArgs.screenDimensions.y);
            pixelCount /= 2 * cameraArgs.data[0].tangentFactor;
            pixelCount *= renderArgs.upscaleFactor;
            
            float reductionFactor = pixelCount / renderArgs.criticalPixelCount;
            if (intersect.distance > 0.100 && reductionFactor < 1) {
              sampleCount *= reductionFactor;
            }
            sampleCount = ceil(sampleCount);
          }
          
          // Prevent infinite loops from corrupted constant data. This is also
          // where we apply the constraint that sampleCount >= 3.
          sampleCount = max(sampleCount, float(3));
          sampleCount = min(sampleCount, float(100));
          
          // Create a generation context.
          GenerationContext generationContext;
          generationContext.seed = RayGeneration::createSeed(
            pixelCoords, renderArgs.frameSeed);
          
          // Iterate over the AO samples.
          for (float i = 0; i < sampleCount; ++i) {
            // Spawn a secondary ray.
            float3 secondaryRayOrigin = hitPoint + 1e-4 * float3(hitNormal);
            float3 secondaryRayDirection = generationContext
              .secondaryRayDirection(i, sampleCount, hitPoint, hitNormal);
            
            // Intersect the secondary ray.
            IntersectionQuery query;
            query.rayOrigin = secondaryRayOrigin;
            query.rayDirection = secondaryRayDirection;
            IntersectionResult intersect = rayIntersector.intersectAO(query);
            
            float diffuseAmbient = 1;
            float specularAmbient = 1;
            if (intersect.accept && intersect.distance < 1) {
              float4 atom = atoms[intersect.atomID];
              uint atomicNumber = \(atomicNumber("atom[3]"));
              ambientOcclusion.computeAmbientContribution(
                diffuseAmbient,
                specularAmbient,
                atomicNumber,
                intersect.distance);
            }
            
            // Accumulate into the sum of AO samples.
            ambientOcclusion.diffuseAccumulator += diffuseAmbient;
            ambientOcclusion.specularAccumulator += specularAmbient;
          }
          
          // Divide the sum by the AO sample count.
          ambientOcclusion.diffuseAccumulator /= sampleCount;
          ambientOcclusion.specularAccumulator /= sampleCount;
        }
        
        // Prepare the Blinn-Phong lighting.
        BlinnPhongLighting blinnPhong;
        blinnPhong.lambertianAccumulator = 0;
        blinnPhong.specularAccumulator = 0;
        blinnPhong.enableAO = (renderArgs.secondaryRayCount > 0);
        
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
