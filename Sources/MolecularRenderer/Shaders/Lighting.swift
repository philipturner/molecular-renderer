func createLightingUtility() -> String {
  return """
  struct AmbientOcclusion {
    // Make this default to 0 (neutronium), which indicates no intersection.
    uint diffuseAtomicNumber = 0;
    
    // Initialize the accumulators for ambient occlusion.
    float diffuseAccumulator = 0;
    float specularAccumulator = 0;
    
    void addAmbientContribution(uint atomicNumber, float distance) {
      float diffuseAmbient;
      float specularAmbient;
      
      // Branch on whether the secondary ray hit an atom.
      if (atomicNumber > 0 && distance < 1.000) {
        // Gaussians function always returns something between 0 and 1.
        // With the distance cutoff, it maps [0 nm, 1 nm] to [1.000, 0.135].
        float occlusion = exp(-2 * distance * distance);
        
        // A simple implementation is 'diffuseAmbient = 1 - occlusion'.
        // This implementation would map [1.000, 0.135] to [0.000, 0.865].
        //
        // A complex implementation imposes a minimum ambient illumination.
        // The actual implementation maps [1.000, 0.135] to [0.070, 0.874].
        diffuseAmbient = 1 - 0.93 * occlusion;
        specularAmbient = 1 - 0.93 * occlusion;
        
        // Color at the primary hit point.
        float3 primaryHitColor = atomColors[diffuseAtomicNumber];
        
        // Color at the secondary hit point.
        float3 secondaryHitColor = atomColors[atomicNumber];
        
        // Take the dot product of the color with the gamut.
        // - Parameters taken from the sRGB/Rec.709 standard.
        // - RGB (0.00, 0.00, 0.00) maps to luminance = 0.
        // - RGB (1.00, 1.00, 1.00) maps to luminance = 1.
        // - Other colors fall somewhere in between.
        float3 gamut = float3(0.212671, 0.715160, 0.072169);
        float primaryHitLuminance = dot(primaryHitColor, gamut);
        float secondaryHitLuminance = dot(secondaryHitColor, gamut);
        
        // Average the luminance at the primary and secondary hit points.
        // - This implementation uses the arithmetic mean.
        // - The original text used geometric mean, but arithmetic mean appears
        //   to work just as well.
        float averageLuminance = 0;
        averageLuminance += primaryHitLuminance;
        averageLuminance += secondaryHitLuminance;
        averageLuminance /= 2;
        
        // Luminance [0, 1] maps to rho [0, 0.5].
        float rho = 0.5 * averageLuminance;
        
        // Adjust the diffuse AO term, to simulate diffuse interreflectance
        // between the primary and secondary hit point.
        diffuseAmbient = diffuseAmbient / (1 - rho * (1 - diffuseAmbient));
      } else {
        diffuseAmbient = 1.000;
        specularAmbient = 1.000;
      }
      
      // Accumulate into the sum of AO samples.
      diffuseAccumulator += diffuseAmbient;
      specularAccumulator += specularAmbient;
    }
    
    void finishAmbientContributions(uint sampleCount) {
      // Divide the sum by the AO sample count.
      diffuseAccumulator /= float(sampleCount);
      this- /= float(sampleCount);
    }
    
    float lambertian;
    float specular;
    
    void startLightContributions() {
      this->lambertian = 0;
      this->specular = 0;
    }
    
    // Add the contributions from a single light (this function allows for a
    // scene to have many).
    void addLightContribution(float3 hitPoint,
                              float3 normal,
                              float3 lightPosition) {
      // From https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model:
      float3 lightDirection = lightPosition - hitPoint;
      lightDirection = normalize(lightDirection);
      
      float lambertian = max(dot(lightDirection, float3(normal)), 0.0);
      this->lambertian += lambertian;
      
      if (lambertian > 0.0) {
        // QuteMol preset 3 seemed most appropriate in a side-by-side comparison
        // between all three presets:
        // https://github.com/zulman/qutemol/blob/master/src/presets/qutemol3.preset
        //
        // Changing the 0.5 specular contribution to 0.25.
        float specContribution = 0.25;
        float shininess = 64;
        
        // 'halfDir' equals 'viewDir' equals 'lightDir' in this case.
        float specAngle = lambertian;
        float contribution = specContribution;
        this->specular += contribution * pow(specAngle, shininess);
      }
    }
    
    float3 createColor() const {
      // Combining using heuristics from:
      // http://research.tri-ace.com/Data/cedec2011_RealtimePBR_Implementation_e.pptx
      float diffuseTerm = 1;
      float specularTerm = 1;
      
      // Disabled for now because the sample count is 0.
      if (false) {
        diffuseTerm = diffuseAmbient;
        
        // This seems to only be applied to a "specular ambient" term, not the
        // "specular direct" term. We are applying it to the latter. However, it
        // seems to produce results we desire: avoid multiplication of the AO
        // term with the specular term, without making the specular term stand out
        // in low-light areas.
        //
        // SO = saturate((lambertian + ambient)^2 - 1 + ambient)
        //
        // SO      | AO = 0.9 | AO = 0.7 | AO = 0.5 | AO = 0.3 | AO = 0.1 |
        // ------- | -------- | -------- | -------- | -------- | -------- |
        // L = 0.9 | 1        | 1        | 1        | 0.74     | 0.1      |
        // L = 0.7 | 1        | 1        | 0.94     | 0.30     | 0        |
        // L = 0.5 | 1        | 1        | 0.50     | 0.14     | 0        |
        // L = 0.3 | 1        | 0.7      | 0.14     | 0        | 0        |
        // L = 0.1 | 0.9      | 0.34     | 0        | 0        | 0        |
        
        specularTerm = lambertian + specularAmbient;
        specularTerm = specularTerm * specularTerm;
        specularTerm += specularAmbient - 1;
        specularTerm = saturate(specularTerm);
      }
      
      float3 color = atomColors[diffuseAtomicNumber];
      color *= float(lambertian * diffuseTerm);
      color += float3(specular * specularTerm);
      return saturate(color);
    }
  };
  """
}
