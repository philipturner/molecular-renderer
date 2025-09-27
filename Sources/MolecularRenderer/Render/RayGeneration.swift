func createRayGeneration() -> String {
  func lerp() -> String {
    #if os(macOS)
    "mix"
    #else
    "lerp"
    #endif
  }
  
  func mul(
    _ lhs: String,
    _ rhs: String
  ) -> String {
    #if os(macOS)
    "\(lhs) * \(rhs)"
    #else
    "mul(\(lhs), \(rhs))"
    #endif
  }
  
  return """
  \(createMatrixUtility())
  \(createSamplingUtility())
  
  // Partially sourced from:
  // https://github.com/nvpro-samples/gl_vk_raytrace_interop/blob/master/shaders/raygen.rgen
  // https://github.com/microsoft/DirectX-Graphics-Samples/tree/master/Samples/Desktop/D3D12Raytracing/src/D3D12RaytracingRealTimeDenoisedAmbientOcclusion/RTAO
  
  namespace RayGeneration {
    struct Basis {
      // Basis for the coordinate system around the normal vector.
      Matrix3x3 axes;
      
      // Uniformly distributed random numbers for determining angles.
      float random1;
      float random2;
    };
    
    Matrix3x3 createAxes(float3 normal) {
      // Set the Z axis to the normal.
      float3 z = normal;
      
      // Compute the Y axis.
      float3 y;
      if (abs(z.z) > 0.999) {
        y[0] = -z.x * z.y;
        y[1] = 1 - z.y * z.y;
        y[2] = -z.y * z.z;
      } else {
        y[0] = -z.x * z.z;
        y[1] = -z.y * z.z;
        y[2] = 1 - z.z * z.z;
      }
      y = normalize(y);
      
      // Compute the X axis through Gram-Schmidt orthogonalization.
      float3 x = cross(y, z);
      
      Matrix3x3 output;
      output.col0 = x;
      output.col1 = y;
      output.col2 = z;
      return output;
    }
    
    float3 primaryRayDirection(uint2 pixelCoords,
                               uint2 screenDimensions,
                               float tangentFactor,
                               Matrix3x3 cameraBasis)
    {
      // Prepare the screen-space coordinates.
      float2 screenCoords = float2(pixelCoords) + 0.5;
      screenCoords /= float2(screenDimensions);
      screenCoords = screenCoords * 2 - 1;
      screenCoords.x *= float(screenDimensions.x) / float(screenDimensions.y);
      screenCoords.y = -screenCoords.y;
      
      // Apply the tangent factor.
      screenCoords *= tangentFactor;
      
      // Prepare the ray direction.
      float3 rayDirection = float3(screenCoords, -1);
      rayDirection = normalize(rayDirection);
      rayDirection = cameraBasis.multiply(rayDirection);
      return rayDirection;
    }
    
    float3 secondaryRayDirection(Basis basis) {
      // Transform the uniform distribution into the cosine distribution. This
      // creates a direction vector that's already normalized.
      float phi = \(2 * Float.pi) * basis.random1;
      float cosThetaSquared = basis.random2;
      float sinTheta = sqrt(1.0 - cosThetaSquared);
      float3 direction = float3(
        cos(phi) * sinTheta,
        sin(phi) * sinTheta,
        sqrt(cosThetaSquared));
      
      // Apply the basis as a linear transformation.
      direction = basis.axes.multiply(direction);
      return direction;
    }
    
    uint createSeed(uint2 pixelCoords,
                    uint frameSeed)
    {
      uint pixelSeed = pixelCoords.x + (pixelCoords.y << 16);
      uint seed1 = Sampling::tea(pixelSeed, frameSeed);
      
      // Compress the seed from 32 bits to 8 bits.
      uint seed2 = (seed1 & 0xFFFF) ^ (seed1 >> 16);
      uint seed3 = (seed2 & 0xFF) ^ (seed2 >> 8);
      return seed3;
    }
  };
  
  struct GenerationContext {
    // WARNING: Remember to initialize this.
    uint seed;
    
    float3 secondaryRayDirection(uint i,
                                 uint sampleCount,
                                 float3 hitPoint,
                                 float3 normal)
    {
      // Generate a random number and increment the seed.
      float random1 = Sampling::radinv3(seed);
      float random2 = Sampling::radinv2(seed);
      seed = (seed + 1) % 256;
      
      if (sampleCount >= 3) {
        float sampleCountRecip = 1 / float(sampleCount);
        float minimum = float(i) * sampleCountRecip;
        float maximum = minimum + sampleCountRecip;
        maximum = (i == sampleCount - 1) ? 1 : maximum;
        random1 = \(lerp())(minimum, maximum, random1);
      }
      
      // Align the atoms' coordinate systems with each other, to minimize
      // divergence. Here is a primitive method that achieves that by aligning
      // the X and Y dimensions to a common coordinate space.
      
      Matrix3x3 rotation;
      rotation.col0 = float3(1, 0, 0);
      rotation.col1 = float3(0, 1, 0);
      rotation.col2 = float3(0, 0, 1);
      
      float3 modNormal = rotation.transpose().multiply(normal);
      Matrix3x3 axes32 = RayGeneration::createAxes(modNormal);
      Matrix3x3 axes16 = rotation.multiply(axes32);
      
      // Create a random ray from the cosine distribution.
      RayGeneration::Basis basis;
      basis.axes = axes16;
      basis.random1 = random1;
      basis.random2 = random2;
      return RayGeneration::secondaryRayDirection(basis);
    }
  };
  """
}
