//
//  Lighting.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 5/21/23.
//

#ifndef LIGHTING_H
#define LIGHTING_H

#include <metal_stdlib>
#include "../Ray/RayIntersector.metal"
#include "../Utilities/Constants.metal"
using namespace metal;

// Handle specular and diffuse color, and transform raw AO hits into
// meaningful color contributions.
class ColorContext {
  constant half3* elementColors;
  
  ushort2 pixelCoords;
  half3 color;
  half2 motionVector;
  float depth;
  
  half3 diffuseColor;
  half diffuseAmbient;
  half specularAmbient;
  half lambertian;
  half specular;
  
public:
  ColorContext(constant half3* elementColors, ushort2 pixelCoords) {
    this->elementColors = elementColors;
    this->pixelCoords = pixelCoords;
    
    // Create a default color for the background.
    this->color = half3(0.707, 0.707, 0.707);
    this->motionVector = half2(0);
    this->depth = -FLT_MAX;
    
    // Initialize the accumulators for lighting.
    this->diffuseAmbient = 0;
    this->specularAmbient = 0;
  }
  
  void setDiffuseColor(ushort atomicNumber) {
    half3 elementColor = elementColors[atomicNumber];
    diffuseColor = elementColor;
  }
  
  void addAmbientContribution(IntersectionResult intersect,
                              device half4 *atomMotionVectors) {
    float diffuseAmbient = 1;
    float specularAmbient = 1;
    
    if (intersect.accept) {
      constexpr float decayConstant = 2.0;
      constexpr float diffuseReflectanceScale = 0.5;
      constexpr float maximumRayHitTime = 1.0;
      constexpr float minimumAmbientIllumination = 0.07;
      
      float t = intersect.distance / maximumRayHitTime;
      float lambda = decayConstant;
      float occlusion = exp(-lambda * t * t);
      diffuseAmbient -= (1 - minimumAmbientIllumination) * occlusion;
      
      // Diffuse interreflectance should affect the final diffuse term, but
      // not the final specular term.
      specularAmbient = diffuseAmbient;
      
      constexpr half3 gamut(0.212671, 0.715160, 0.072169); // sRGB/Rec.709
      float luminance = dot(diffuseColor, gamut);
      
      // Account for the color of the occluding atom. This decreases the
      // contrast between differing elements placed near each other. It also
      // makes the effect vary around the atom's surface.
      float neighborLuminance;
      {
        half4 motionVector = atomMotionVectors[intersect.atomID];
        ushort atomicNumber = as_type<ushort>(motionVector.w);
        half3 elementColor = elementColors[atomicNumber];
        neighborLuminance = dot(elementColor, gamut);
      }
      
      // Use the arithmetic mean. There is no perceivable difference from
      // the (presumably more accurate) geometric mean.
      luminance = (luminance + neighborLuminance) / 2;
      
      float kA = diffuseAmbient;
      float rho = diffuseReflectanceScale * luminance;
      diffuseAmbient = kA / (1 - rho * (1 - kA));
    }
    
    this->diffuseAmbient += diffuseAmbient;
    this->specularAmbient += specularAmbient;
  }
  
  void finishAmbientContributions(half samples) {
    float sampleCountRecip = 1 / float(samples);
    this->diffuseAmbient *= sampleCountRecip;
    this->specularAmbient *= sampleCountRecip;
  }
  
  void startLightContributions() {
    this->lambertian = 0;
    this->specular = 0;
  }
  
  void addLightContribution(float3 hitPoint,
                            half3 normal,
                            float3 lightPosition) {
    // From https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model:
    float3 lightDirection = lightPosition - hitPoint;
    float rsqrtLightDst = rsqrt(length_squared(lightDirection));
    lightDirection *= rsqrtLightDst;
    
    float lambertian = max(dot(lightDirection, float3(normal)), 0.0);
    this->lambertian += lambertian;
    
    if (lambertian > 0.0) {
      // QuteMol preset 3 seemed most appropriate in a side-by-side comparison
      // between all three presets:
      // https://github.com/zulman/qutemol/blob/master/src/presets/qutemol3.preset
      //
      // Changing the 0.5 specular contribution to 0.25.
      constexpr float specContribution = 0.25;
      constexpr float shininess = 64;
      
      // 'halfDir' equals 'viewDir' equals 'lightDir' in this case.
      float specAngle = lambertian;
      float contribution = specContribution;
      this->specular += contribution * pow(specAngle, shininess);
    }
  }
  
  void applyContributions() {
    // Combining using heuristics from:
    // http://research.tri-ace.com/Data/cedec2011_RealtimePBR_Implementation_e.pptx
    float ambientOcclusion = 1;
    float specularOcclusion = 1;
    
    {
      ambientOcclusion = this->diffuseAmbient;
      specularOcclusion = this->specularAmbient;
      
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
      
      specularOcclusion = lambertian + specularAmbient;
      specularOcclusion = specularOcclusion * specularOcclusion;
      specularOcclusion += specularAmbient - 1;
      specularOcclusion = saturate(specularOcclusion);
    }
    
    // Store color in single precision while calculating.
    float3 color = float3(diffuseColor) * lambertian * ambientOcclusion;
    color += specular * specularOcclusion;
    this->color = half3(saturate(color));
  }
  
  void setDepth(float depth) {
    this->depth = depth;
  }
  
  void generateMotionVector(constant CameraArguments *cameraArgs,
                            constant RenderArguments *renderArgs,
                            float3 hitPoint) {
    // Apply the camera position.
    float3 cameraPosition = cameraArgs->position;
    float3 direction = normalize(hitPoint - cameraPosition);
    
    // Apply the camera direction.
    float3x3 rotation(cameraArgs->rotationColumn1,
                      cameraArgs->rotationColumn2,
                      cameraArgs->rotationColumn3);
    direction = transpose(rotation) * direction;
    
    // Apply the camera FOV.
    float fovMultiplier = cameraArgs->fovMultiplier;
    direction *= 1 / fovMultiplier / direction.z;
    
    // I have no idea why, but the X coordinate is flipped here.
    float2 prevCoords = direction.xy;
    prevCoords.x = -prevCoords.x;
    
    // Recompute the current pixel coordinates (do not waste registers).
    float2 currCoords = float2(pixelCoords) + 0.5;
    currCoords += renderArgs->jitterOffsets;
    currCoords.xy -= float2(SCREEN_WIDTH, SCREEN_HEIGHT) / 2;
    
    // Generate the motion vector from pixel coordinates.
    motionVector = half2(currCoords - prevCoords);
    
    // I have no idea why, but the coordinates are flipped here.
    motionVector.y = -motionVector.y;
    motionVector.x = -motionVector.x;
  }
  
  void write_offline(texture2d<half, access::write> colorTexture) {
    float3 color_float = float3(color);
    color_float = quad_sum(color_float) / 4;
    half4 color_half = half4(half3(color_float), 1);
    colorTexture.write(color_half, pixelCoords / 2);
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

#endif // LIGHTING_H
