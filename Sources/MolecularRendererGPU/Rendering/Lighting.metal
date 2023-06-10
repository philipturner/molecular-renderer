//
//  Lighting.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 5/21/23.
//

#include <metal_stdlib>
#include "Constants.metal"
#include "RayTracing.metal"
using namespace metal;

// Handle specular and diffuse color, and transform raw AO hits into
// meaningful color contributions.
class ColorContext {
  constant Arguments* args;
  constant MRAtomStatistics* atomData;
  
  ushort2 pixelCoords;
  half3 color;
  half2 motionVector;
  float depth;
  
  half3 diffuseColor;
  float lambertian;
  float specular;
  float diffuseAmbient;
  float specularAmbient;
  float lightPower;
  
public:
  ColorContext(constant Arguments* args,
               constant MRAtomStatistics* atomData, ushort2 pixelCoords) {
    this->args = args;
    this->atomData = atomData;
    this->pixelCoords = pixelCoords;
    
    // Create a default color for the background.
    this->color = half3(0.707, 0.707, 0.707);
    this->motionVector = half2(0);
    this->depth = -FLT_MAX;
    
    // Initialize the accumulator for ambient occlusion.
    this->diffuseAmbient = 0;
    this->specularAmbient = 0;
  }
  
  void setDiffuseColor(MRAtom atom, float3 normal) {
    if (atom.flags & 0x2) {
      // Replace the diffuse color with black.
      diffuseColor = { 0.000, 0.000, 0.000 };
    } else {
      diffuseColor = atom.getColor(atomData);
    }
    
    // Apply checkerboard to tagged atoms.
    if (atom.flags & 0x1) {
      // Determine whether the axes are positive.
      bool3 axes_pos(normal > 0);
      bool is_magenta = axes_pos.x ^ axes_pos.y ^ axes_pos.z;
      
      half3 magenta(252.0 / 255, 0.0 / 255, 255.0 / 255);
      diffuseColor = is_magenta ? magenta : diffuseColor;
    }
  }
  
  half3 getDiffuseColor() const {
    return this->diffuseColor;
  }
  
  void addAmbientContribution(float diffuse, float specular) {
    this->diffuseAmbient += diffuse;
    this->specularAmbient += specular;
  }
  
  void setDepth(float depth) {
    this->depth = depth;
  }
  
  void setLightContributions(float3 hitPoint, float3 normal) {
    // From https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model:
    float3 lightDirection = args->position - hitPoint;
    float rsqrtLightDst = rsqrt(length_squared(lightDirection));
    lightDirection *= rsqrtLightDst;
    
    this->lambertian = max(dot(lightDirection, normal), 0.0);
    this->specular = 0;
    if (lambertian > 0.0) {
      // QuteMol preset 3 seemed most appropriate in a side-by-side comparison
      // between all three presets:
      // https://github.com/zulman/qutemol/blob/master/src/presets/qutemol3.preset
      constexpr float specContribution = 0.5;
      constexpr float shininess = 64;
      
      // 'halfDir' equals 'viewDir' equals 'lightDir' in this case.
      float specAngle = lambertian;
      specular = specContribution * pow(specAngle, shininess);
    }
    
    this->lightPower = float(args->lightPower);
    this->lightPower = smoothstep(0, 1, lightPower * rsqrtLightDst);
  }
  
  void applyLightContributions() {
    // Combining using heuristics from:
    // http://research.tri-ace.com/Data/cedec2011_RealtimePBR_Implementation_e.pptx
    float ambientOcclusion = 1;
    float specularOcclusion = 1;
    if (args->sampleCount > 0) {
      float sampleCountRecip = fast::divide(1, args->sampleCount);
      float diffuseAmbient = this->diffuseAmbient * sampleCountRecip;
      float specularAmbient = this->specularAmbient * sampleCountRecip;
      ambientOcclusion = diffuseAmbient;
      
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
      
      if (SUPPRESS_SPECULAR) {
        specularOcclusion = specularAmbient;
      } else {
        specularOcclusion = lambertian + specularAmbient;
        specularOcclusion = specularOcclusion * specularOcclusion;
        specularOcclusion += specularAmbient - 1;
        specularOcclusion = saturate(specularOcclusion);
      }
    }
    
    // Store color in single precision while calculating.
    float3 newColor = float3(diffuseColor) * lambertian * ambientOcclusion;
    newColor += specular * specularOcclusion;
    newColor *= lightPower;
    this->color = half3(saturate(newColor));
  }
  
  void generateMotionVector(float3 hitPoint) {
    float3 direction = normalize(hitPoint - args[1].position);
    direction = transpose(args[1].cameraToWorldRotation) * direction;
    direction *= args[1].fov90Span / direction.z;
    
    // I have no idea why, but the X coordinate is flipped here.
    float2 prevCoords = direction.xy;
    prevCoords.x = -prevCoords.x;
    
    // Recompute the current pixel coordinates (do not waste registers).
    float2 currCoords = float2(pixelCoords) + 0.5;
    currCoords.xy -= float2(SCREEN_WIDTH, SCREEN_HEIGHT) / 2;
    
    // Generate the motion vector from pixel coordinates.
    motionVector = half2(currCoords - prevCoords);
    
    // I have no idea why, but the Y coordinate is flipped here.
    motionVector.y = -motionVector.y;
  }
  
  void write(texture2d<half, access::write> colorTexture,
             texture2d<float, access::write> depthTexture,
             texture2d<half, access::write> motionTexture)
  {
    // Write the output color.
    half4 writtenColor(color, 1);
    colorTexture.write(writtenColor, pixelCoords);
    
    // Adjust the depth and motion vector.
    auto depth = 1 / float(1 - this->depth); // map (0, -infty) to (1, 0)
    auto motionVector = clamp(this->motionVector, -HALF_MAX, HALF_MAX);
    
    // Write the output depth.
    float4 writtenDepth{ depth };
    depthTexture.write(writtenDepth, pixelCoords);
    
    // Write the output motion vector.
    half4 writtenMotionVector{ motionVector.x, motionVector.y };
    motionTexture.write(writtenMotionVector, pixelCoords);
  }
};
