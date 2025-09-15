func createRayGeneration() -> String {
  return """
  \(createSamplingUtility())
  
  // Partially sourced from:
  // https://github.com/nvpro-samples/gl_vk_raytrace_interop/blob/master/shaders/raygen.rgen
  // https://github.com/microsoft/DirectX-Graphics-Samples/tree/master/Samples/Desktop/D3D12Raytracing/src/D3D12RaytracingRealTimeDenoisedAmbientOcclusion/RTAO
  
  namespace RayGeneration {
    struct Basis {
      // Basis for the coordinate system around the normal vector.
      float3x3 axes;
      
      // Uniformly distributed random numbers for determining angles.
      float random1;
      float random2;
    };
    
    float3x3 makeBasis(float3 normal) {
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
      return float3x3(x, y, z);
    }
    
    float3 secondaryRayDirection(Basis basis) {
      // Transform the uniform distribution into the cosine distribution. This
      // creates a direction vector that's already normalized.
      float phi = \(2 * Float.pi) * basis.random1;
      float cosThetaSquared = basis.random2;
      float sinTheta = sqrt(1.0 - cosThetaSquared);
      float3 direction(cos(phi) * sinTheta,
                       sin(phi) * sinTheta,
                       sqrt(cosThetaSquared));
      
      // Apply the basis as a linear transformation.
      direction = float3x3(basis.axes) * direction;
      return direction;
    }
    
    uint createSeed(uint2 pixelCoords,
                    uint frameSeed)
    {
      uint frameSeed = renderArgs->frameSeed;
      uint pixelSeed = pixelCoords.x + (pixelCoords.y << 16);
      uint seed1 = Sampling::tea(pixelSeed, frameSeed);
      
      // Compress the seed from 32 bits to 8 bits.
      uint seed2 = (seed1 & 0xFFFF) ^ (seed1 >> 16);
      uint seed3 = (seed2 & 0xFF) ^ (seed2 >> 8);
      return seed3;
    }
    
    float3 secondaryRayDirection(ushort i,
                                ushort samples,
                                float3 hitPoint,
                                half3 normal)
    {
      // Generate a random number and increment the seed.
      float random1 = Sampling::radinv3(seed);
      float random2 = Sampling::radinv2(seed);
      seed += 1;
      
      if (samples >= 3) {
        float sampleCountRecip = fast::divide(1, float(samples));
        float minimum = float(i) * sampleCountRecip;
        float maximum = minimum + sampleCountRecip;
        maximum = (i == samples - 1) ? 1 : maximum;
        random1 = mix(minimum, maximum, random1);
      }
      
      // Align the atoms' coordinate systems with each other, to minimize
      // divergence. Here is a primitive method that achieves that by aligning
      // the X and Y dimensions to a common coordinate space.
      float3x3 rotation(cameraArgs->rotationColumn1,
                        cameraArgs->rotationColumn2,
                        cameraArgs->rotationColumn3);
      float3 modNormal = transpose(rotation) * float3(normal);
      float3x3 axes32 = RayGeneration::makeBasis(modNormal);
      half3x3 axes16 = half3x3(rotation * axes32);
      
      // Create a random ray from the cosine distribution.
      RayGeneration::Basis basis { axes16, random1, random2 };
      return RayGeneration::secondaryRayDirection(basis);
    }
  };
  """
}
