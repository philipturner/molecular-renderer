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
  constant AtomStatistics* atomData;
  
  ushort2 pixelCoords;
  half3 color;
  half2 motionVector;
  float depth;
  
  half3 diffuseColor;
  float lambertian;
  float specular;
  float occlusion;
  float lightPower;
  
public:
  ColorContext(constant Arguments* args,
               constant AtomStatistics* atomData, ushort2 pixelCoords) {
    this->args = args;
    this->atomData = atomData;
    this->pixelCoords = pixelCoords;
    
    // Create a default color for the background.
    this->color = half3(0.707, 0.707, 0.707);
    this->motionVector = half2(0);
    this->depth = -FLT_MAX;
    
    // Initialize the accumulator for ambient occlusion.
    this->occlusion = 0;
  }
  
  void setDiffuseColor(Atom atom, float3 normal) {
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
  
  void addOcclusion(float contribution) {
    // TODO: Add exponential falloff from DX sample.
    this->occlusion += contribution;
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
      constexpr float shininess = 16.0;
      
      // 'halfDir' equals 'viewDir' equals 'lightDir' in this case.
      float specAngle = lambertian;
      specular = pow(specAngle, shininess);
    }
    
    // TODO: The specular part looks very strange for colors besides gray.
    // Determine what QuteMol does to fix this.
    this->lightPower = 40.0;
    this->lightPower = smoothstep(0, 1, lightPower * rsqrtLightDst);
  }
  
  void applyLightContributions() {
    // Store color in single precision while calculating.
    float3 newColor = float3(diffuseColor) * lambertian * lightPower;
    newColor += specular * lightPower;
    
    // TODO: Do you apply occlusion before or after the specular part?
    if (USE_RTAO) {
      float occlusion = this->occlusion;
      occlusion = 1 - (occlusion / float(RTAO_SAMPLES));
      occlusion = pow(saturate(occlusion), RTAO_POWER);
      newColor *= occlusion;
    }
    this->color = half3(saturate(newColor));
  }
  
  void generateMotionVector(float3 hitPoint) {
    float3 direction = normalize(hitPoint - args[1].position);
    direction = transpose(args[1].rotation) * direction;
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
    
    if (USE_METALFX) {
      this->depth = 1 / float(1 - depth); // map (0, -infty) to (1, 0)
      this->motionVector = clamp(motionVector, -HALF_MAX, HALF_MAX);
      
      // Write the output depth.
      float4 writtenDepth{ depth };
      depthTexture.write(writtenDepth, pixelCoords);
      
      // Write the output motion vector.
      half4 writtenMotionVector{ motionVector.x, motionVector.y };
      motionTexture.write(writtenMotionVector, pixelCoords);
    }
  }
};
