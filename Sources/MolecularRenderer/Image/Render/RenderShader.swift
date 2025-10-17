struct RenderShader {
  // [numthreads(8, 8, 1)]
  // dispatch threads SIMD3(colorTexture.width, colorTexture.height, 1)
  // threadgroup memory 4096 B
  static func createSource(
    upscaleFactor: Float,
    worldDimension: Float
  ) -> String {
    // atoms.atoms
    // atoms.motionVectors
    // voxels.group.occupiedMarks
    // voxels.dense.assignedSlotIDs
    // voxels.sparse.memorySlots [32, 16]
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
        \(CrashBuffer.functionArguments),
        constant RenderArgs &renderArgs [[buffer(\(Self.renderArgs))]],
        constant CameraArgsList &cameraArgs [[buffer(\(Self.cameraArgs))]],
        device float4 *atoms [[buffer(\(Self.atoms))]],
        device half4 *motionVectors [[buffer(\(Self.motionVectors))]],
        device uint *voxelGroupOccupiedMarks [[buffer(\(Self.voxelGroupOccupiedMarks))]],
        device uint *assignedSlotIDs [[buffer(\(Self.assignedSlotIDs))]],
        device uint *memorySlots32 [[buffer(\(Self.memorySlots32))]],
        device ushort *memorySlots16 [[buffer(\(Self.memorySlots16))]],
        texture2d<float, access::write> colorTexture [[texture(\(Self.colorTexture))]],
        \(optionalFunctionArguments())
        uint2 pixelCoords [[thread_position_in_grid]])
      """
      #else
      let byteCount = MemoryLayout<RenderArgs>.size
      
      return """
      \(CrashBuffer.functionArguments)
      ConstantBuffer<RenderArgs> renderArgs : register(b\(Self.renderArgs));
      ConstantBuffer<CameraArgsList> cameraArgs : register(b\(Self.cameraArgs));
      RWStructuredBuffer<float4> atoms : register(u\(Self.atoms));
      RWBuffer<float4> motionVectors : register(u\(Self.motionVectors));
      RWStructuredBuffer<uint> voxelGroupOccupiedMarks : register(u\(Self.voxelGroupOccupiedMarks));
      RWStructuredBuffer<uint> assignedSlotIDs : register(u\(Self.assignedSlotIDs));
      RWStructuredBuffer<uint> memorySlots32 : register(u\(Self.memorySlots32));
      RWBuffer<uint> memorySlots16 : register(u\(Self.memorySlots16));
      RWTexture2D<float4> colorTexture : register(u\(Self.colorTexture));
      \(optionalFunctionArguments())
      groupshared uint2 memoryTape[8 * 64];
      
      [numthreads(8, 8, 1)]
      [RootSignature(
        \(CrashBuffer.rootSignatureArguments)
        "RootConstants(b\(Self.renderArgs), num32BitConstants = \(byteCount / 4)),"
        "CBV(b\(Self.cameraArgs)),"
        "UAV(u\(Self.atoms)),"
        "DescriptorTable(UAV(u\(Self.motionVectors), numDescriptors = 1)),"
        "UAV(u\(Self.voxelGroupOccupiedMarks)),"
        "UAV(u\(Self.assignedSlotIDs)),"
        "UAV(u\(Self.memorySlots32)),"
        "DescriptorTable(UAV(u\(Self.memorySlots16), numDescriptors = 1)),"
        "DescriptorTable(UAV(u\(Self.colorTexture), numDescriptors = 1)),"
        \(optionalRootSignatureArguments())
      )]
      void render(
        uint2 pixelCoords : SV_DispatchThreadID)
      """
      #endif
    }
    
    func allocateThreadgroupMemory() -> String {
      #if os(macOS)
      "threadgroup uint2 memoryTape[8 * 64];"
      #else
      ""
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
        screenCoords.x *= float(screenDimensions.y) / float(screenDimensions.x);
        screenCoords = (screenCoords + 1) / 2;
        float2 previousPixelCoords = screenCoords * float2(screenDimensions);
        
        // Compare against current coordinates.
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
    
    func atomicNumber(_ input: String) -> String {
      "\(Shader.asuint)(\(input)) & 0xFF"
    }
    
    return """
    \(Shader.importStandardLibrary)
    
    \(AtomStyles.createAtomColors(AtomStyles.colors))
    \(createMatrixUtility())
    \(createRayGeneration())
    \(createRayIntersector(worldDimension: worldDimension))
    \(createLightingUtility())
    
    \(RenderArgs.shaderDeclaration)
    \(CameraArgs.shaderDeclaration)
    struct CameraArgsList {
      CameraArgs data[2];
    };
    
    \(functionSignature())
    {
      \(allocateThreadgroupMemory())
      
      // Query the screen's dimensions.
      \(queryScreenDimensions())
      if ((pixelCoords.x >= screenDimensions.x) ||
          (pixelCoords.y >= screenDimensions.y)) {
        return;
      }
      
      if (crashBuffer[0] != 1) {
        \(write("float4(0, 0, 0, 0)", texture: "colorTexture"))
        return;
      }
      
      float2 jitterOffset;
      jitterOffset.x = renderArgs.jitterOffsetX;
      jitterOffset.y = renderArgs.jitterOffsetY;
      
      // Prepare the ray intersector.
      RayIntersector rayIntersector;
      rayIntersector.atoms = atoms;
      rayIntersector.voxelGroupOccupiedMarks = voxelGroupOccupiedMarks;
      rayIntersector.assignedSlotIDs = assignedSlotIDs;
      rayIntersector.memorySlots32 = memorySlots32;
      rayIntersector.memorySlots16 = memorySlots16;
      \(bindMemoryTape())
      
      // Prepare the ray direction.
      float dzdt;
      float3 primaryRayDirection =
      RayGeneration::primaryRayDirection(dzdt,
                                         pixelCoords,
                                         screenDimensions,
                                         jitterOffset,
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
        ambientOcclusion.diffuseAtomicNumber = \(atomicNumber("hitAtom[3]"));
        ambientOcclusion.diffuseAccumulator = 0;
        ambientOcclusion.specularAccumulator = 0;
        
        // Change color of the atom to easily identify different tiers
        // of pixel count, and ensure they don't change when upscaling is
        // enabled.
        //
        // carbon: expected 59 px, got 61-64 px
        // silicon: expected 69 px, got 74-76 px
        float pixelCount = 2 * sqrt(hitAtom[3]);
        pixelCount /= (-dzdt * intersect.distance);
        pixelCount *= float(screenDimensions.y);
        pixelCount /= 2 * cameraArgs.data[0].tangentFactor;
        pixelCount *= renderArgs.upscaleFactor;
        
        // Pick the number of AO samples.
        uint sampleCount = 15;
        
        // Prevent infinite loops from corrupted constant data.
        // TODO: If AO is enabled, clamp the sample count to 3...100
        
        // Create a generation context.
        GenerationContext generationContext;
        generationContext.seed = RayGeneration::createSeed(
          pixelCoords, renderArgs.frameSeed);
        
        // Iterate over the AO samples.
        for (uint i = 0; i < sampleCount; ++i) {
          // Spawn a secondary ray.
          float3 secondaryRayOrigin = hitPoint + 1e-4 * float3(hitNormal);
          float3 secondaryRayDirection = generationContext
            .secondaryRayDirection(i, sampleCount, hitPoint, hitNormal);
          
          // Deactivate ray tracing for AO.
          // TODO: Run dummy AO where all atoms are very dark, but only if AO
          // is enabled.
          
          // WARNING: Properly decode the atomic number for the hit atom.
          ambientOcclusion.addAmbientContribution(0, 1e38);
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
