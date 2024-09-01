//
//  RenderAtoms.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
#include "Lighting/Lighting.metal"
#include "Ray/RayGeneration.metal"
#include "Ray/RayTraversal.metal"
#include "Utilities/Constants.metal"
using namespace metal;

kernel void renderAtoms
(
 constant CameraArguments *cameraArgs [[buffer(0)]],
 constant RenderArguments *renderArgs [[buffer(1)]],
 constant BVHArguments *bvhArgs [[buffer(2)]],
 constant float3 *elementColors [[buffer(3)]],
 device uint *smallCellOffsets [[buffer(4)]],
 device uint *smallAtomReferences [[buffer(5)]],
 device float4 *convertedAtoms [[buffer(6)]],
 device float4 *convertedAtoms2 [[buffer(7)]],
 device half3 *atomMotionVectors [[buffer(8)]],
 device half3 *atomMotionVectors2 [[buffer(9)]],
 texture2d<half, access::write> colorTexture [[texture(0)]],
 texture2d<float, access::write> depthTexture [[texture(1)]],
 texture2d<half, access::write> motionTexture [[texture(2)]],
 ushort2 tid [[thread_position_in_grid]],
 ushort2 tgid [[threadgroup_position_in_grid]],
 ushort2 lid [[thread_position_in_threadgroup]])
{
  // Return early if outside bounds.
  ushort2 pixelCoords = RayGeneration::makePixelID(tgid, lid);
  if ((SCREEN_WIDTH % 16 != 0) && (pixelCoords.x >= SCREEN_WIDTH)) return;
  if ((SCREEN_HEIGHT % 16 != 0) && (pixelCoords.y >= SCREEN_HEIGHT)) return;
  
  // Initialize the uniform grid.
  DenseGrid grid {
    bvhArgs,
    smallCellOffsets,
    smallAtomReferences,
    convertedAtoms
  };
  
  // Spawn the primary ray.
  auto primaryRay = RayGeneration::primaryRay(cameraArgs, pixelCoords);
  
  // Intersect the primary ray.
  IntersectionParams params { false, MAXFLOAT, false };
  auto intersect = RayIntersector::traverse(primaryRay, grid, params);
  
  // Calculate the contributions from diffuse, specular, and AO.
  auto colorCtx = ColorContext(elementColors, pixelCoords);
  if (intersect.accept) {
    float3 hitPoint = primaryRay.origin;
    hitPoint += primaryRay.direction * intersect.distance;
    
    // Add the contribution from the primary ray.
    half3 normal = half3(normalize(hitPoint - intersect.newAtom.xyz));
    colorCtx.setDiffuseColor(intersect.newAtom);
    
    // Pick the number of AO samples.
    half sampleCount;
    {
      constexpr half minSamples = 3.0;
      constexpr half maxSamples = 7.0;
      
      float distanceCutoff = renderArgs->qualityCoefficient / maxSamples;
      if (intersect.distance > distanceCutoff) {
        half proportion = distanceCutoff / intersect.distance;
        sampleCount = max(minSamples, maxSamples * proportion);
        sampleCount = ceil(sampleCount);
      } else {
        sampleCount = maxSamples;
      }
      sampleCount = max(sampleCount, minSamples);
      sampleCount = min(sampleCount, maxSamples);
    }
    
    // Create a generation context.
    auto genCtx = GenerationContext(cameraArgs,
                                    renderArgs->frameSeed,
                                    pixelCoords);
    
    // Iterate over the AO samples.
    for (half i = 0; i < sampleCount; ++i) {
      // Spawn a secondary ray.
      auto ray = genCtx.generate(i, sampleCount, hitPoint, normal);
      
      // Intersect the secondary ray.
      constexpr half maximumRayHitTime = 1.0;
      IntersectionParams params { true, maximumRayHitTime, false };
      auto intersect = RayIntersector::traverse(ray, grid, params);
      
      // Add the secondary ray's AO contributions.
      colorCtx.addAmbientContribution(intersect);
    }
    
    // Tell the context how many AO samples were taken.
    colorCtx.finishAmbientContributions(sampleCount);
    
    // Apply the camera position.
    {
      float3 lightPosition = cameraArgs->positionAndFOVMultiplier.xyz;
      colorCtx.startLightContributions();
      colorCtx.addLightContribution(hitPoint, normal, lightPosition);
      colorCtx.applyContributions();
    }
    
    // Write the depth as the intersection point's Z coordinate.
    {
      float3 rayDirection = primaryRay.direction;
      float3 cameraDirection = cameraArgs->rotationColumn3;
      float rayDirectionComponent = dot(rayDirection, cameraDirection);
      float depth = rayDirectionComponent * intersect.distance;
      colorCtx.setDepth(depth);
    }
    
    // Find the hit point's position in the previous frame.
    half3 motionVector = atomMotionVectors[intersect.reference];
    float3 previousHitPoint = hitPoint - float3(motionVector);
    
    // Generate the pixel motion vector, being careful to handle the camera
    // arguments correctly.
    {
      auto previousCameraArgs = cameraArgs + 1;
      float2 currentJitter = cameraArgs->jitter;
      colorCtx.generateMotionVector(previousCameraArgs,
                                    currentJitter,
                                    previousHitPoint);
    }
  }
  colorCtx.write(colorTexture, depthTexture, motionTexture);
}
