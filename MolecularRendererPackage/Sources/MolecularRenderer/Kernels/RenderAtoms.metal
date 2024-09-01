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
 constant half3 *elementColors [[buffer(3)]],
 device uint4 *largeCellMetadata [[buffer(4)]],
 device uint *smallCellOffsets [[buffer(5)]],
 device uint *smallAtomReferences [[buffer(6)]],
 device float4 *convertedAtoms [[buffer(7)]],
 device half3 *atomMotionVectors [[buffer(8)]],
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
  
  // Fill the BVH descriptor.
  BVHDescriptor bvhDescriptor;
  bvhDescriptor.bvhArgs = bvhArgs;
  bvhDescriptor.largeCellMetadata = largeCellMetadata;
  bvhDescriptor.smallCellOffsets = smallCellOffsets;
  bvhDescriptor.smallAtomReferences = smallAtomReferences;
  bvhDescriptor.convertedAtoms = convertedAtoms;
  
  // Spawn the primary ray.
  auto primaryRay = RayGeneration::primaryRay(cameraArgs, pixelCoords);
  
  // Intersect the primary ray.
  IntersectionParams params { false, MAXFLOAT };
  IntersectionQuery query;
  query.rayOrigin = primaryRay.origin;
  query.rayDirection = primaryRay.direction;
  query.params = params;
  auto intersect = RayIntersector::traverse(bvhDescriptor,
                                            query);
  
  // Calculate the contributions from diffuse, specular, and AO.
  auto colorCtx = ColorContext(elementColors, pixelCoords);
  if (intersect.accept) {
    float3 hitPoint = primaryRay.origin;
    hitPoint += primaryRay.direction * intersect.distance;
    
    // Add the contribution from the primary ray.
    float4 hitAtom = convertedAtoms[intersect.atomID];
    half3 normal = half3(normalize(hitPoint - hitAtom.xyz));
    colorCtx.setDiffuseColor(hitAtom);
    
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
      auto secondaryRay = genCtx.generate(i, 
                                          sampleCount,
                                          hitPoint,
                                          normal);
      
      // Intersect the secondary ray.
      IntersectionParams params { true, 1.0 };
      IntersectionQuery query;
      query.rayOrigin = secondaryRay.origin;
      query.rayDirection = float3(secondaryRay.direction);
      query.params = params;
      auto intersect = RayIntersector::traverse(bvhDescriptor,
                                                query);
      
      // Add the secondary ray's AO contributions.
      colorCtx.addAmbientContribution(intersect,
                                      convertedAtoms);
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
    half3 motionVector = atomMotionVectors[intersect.atomID];
    float3 previousHitPoint = hitPoint - float3(motionVector);
    
    // Generate the pixel motion vector.
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
