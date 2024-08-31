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
 device uint *smallCellMetadata [[buffer(3)]],
 device uint *smallAtomReferences [[buffer(4)]],
 device float4 *convertedAtoms [[buffer(5)]],
 device float4 *previousAtoms [[buffer(6)]],
 constant float3 *elementColors [[buffer(7)]],
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
    smallCellMetadata,
    smallAtomReferences,
    convertedAtoms
  };
  
  // Cast the primary ray.
  auto ray = RayGeneration::primaryRay(cameraArgs, pixelCoords);
  IntersectionParams params { false, MAXFLOAT, false };
  auto intersect = RayIntersector::traverse(ray, grid, params);
  
  // Calculate ambient occlusion, diffuse, and specular terms.
  auto colorCtx = ColorContext(elementColors, pixelCoords);
  if (intersect.accept) {
    float3 hitPoint = ray.origin + ray.direction * intersect.distance;
    half3 normal = half3(normalize(hitPoint - intersect.newAtom.xyz));
    colorCtx.setDiffuseColor(intersect.newAtom);
    
    // Cast the secondary rays.
    {
      constexpr half minSamples = 3.0;
      constexpr half maxSamples = 7.0;
      constexpr half maximumRayHitTime = 1.0;
      
      half samples = maxSamples;
      float distanceCutoff = renderArgs->qualityCoefficient / maxSamples;
      if (intersect.distance > distanceCutoff) {
        half proportion = distanceCutoff / intersect.distance;
        half newSamples = max(minSamples, samples * proportion);
        samples = clamp(ceil(newSamples), minSamples, maxSamples);
      }
      
      auto genCtx = GenerationContext(cameraArgs,
                                      renderArgs->frameSeed,
                                      pixelCoords);
      for (half i = 0; i < samples; ++i) {
        auto ray = genCtx.generate(i, samples, hitPoint, normal);
        
        IntersectionParams params { true, maximumRayHitTime, false };
        auto intersect = RayIntersector::traverse(ray, grid, params);
        colorCtx.addAmbientContribution(intersect);
      }
      colorCtx.finishAmbientContributions(samples);
    }
    
    // Apply the camera position.
    float3 lightPosition = cameraArgs->positionAndFOVMultiplier.xyz;
    colorCtx.startLightContributions();
    colorCtx.addLightContribution(hitPoint, normal, lightPosition);
    colorCtx.applyContributions();
    
    // Write the depth as the intersection point's Z coordinate.
    float3 cameraDirection = cameraArgs->rotationColumn3;
    float rayDirectionComponent = dot(ray.direction, cameraDirection);
    float depth = rayDirectionComponent * intersect.distance;
    colorCtx.setDepth(depth);
    
    // Find the atom's position in the previous frame.
    float3 previousFramePosition = hitPoint;
    if (renderArgs->useAtomMotionVectors) {
      float3 currentNucleus = convertedAtoms[intersect.reference].xyz;
      float3 previousNucleus = previousAtoms[intersect.reference].xyz;
      previousFramePosition += previousNucleus - currentNucleus;
    }
    
    // Generate the motion vector, being careful to handle the camera
    // arguments correctly.
    auto previousCameraArgs = cameraArgs + 1;
    float2 currentJitter = cameraArgs->jitter;
    colorCtx.generateMotionVector(previousCameraArgs,
                                  currentJitter,
                                  previousFramePosition);
  }
  colorCtx.write(colorTexture, depthTexture, motionTexture);
}
