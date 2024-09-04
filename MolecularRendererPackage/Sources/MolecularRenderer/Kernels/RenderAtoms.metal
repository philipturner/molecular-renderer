//
//  RenderAtoms.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
#include "Lighting/Lighting.metal"
#include "Ray/RayGeneration.metal"
#include "Ray/RayIntersector.metal"
#include "Utilities/Constants.metal"
using namespace metal;

kernel void renderAtoms
(
 constant CameraArguments *cameraArgs [[buffer(0)]],
 constant RenderArguments *renderArgs [[buffer(1)]],
 constant BVHArguments *bvhArgs [[buffer(2)]],
 constant half3 *elementColors [[buffer(3)]],
 device float4 *originalAtoms [[buffer(4)]],
 device half3 *atomMetadata [[buffer(5)]],
 device half4 *convertedAtoms [[buffer(6)]],
 device uint *largeAtomReferences [[buffer(7)]],
 device ushort *smallAtomReferences [[buffer(8)]],
 device uint4 *largeCellMetadata [[buffer(9)]],
 device ushort2 *compactedSmallCellMetadata [[buffer(10)]],
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
  
  // Initialize the ray intersector.
  RayIntersector rayIntersector;
  rayIntersector.bvhArgs = bvhArgs;
  rayIntersector.convertedAtoms = convertedAtoms;
  rayIntersector.smallAtomReferences = smallAtomReferences;
  rayIntersector.largeCellMetadata = largeCellMetadata;
  rayIntersector.compactedSmallCellMetadata = compactedSmallCellMetadata;
  
  // Spawn the primary ray.
  float3 primaryRayOrigin = cameraArgs->position;
  float3 primaryRayDirection =
  RayGeneration::primaryRayDirection(cameraArgs,
                                     renderArgs,
                                     pixelCoords);
  
  // Intersect the primary ray.
  IntersectionQuery query;
  query.isAORay = false;
  query.rayOrigin = primaryRayOrigin;
  query.rayDirection = primaryRayDirection;
  auto intersect = rayIntersector.intersect(query);
  
  // Calculate the contributions from diffuse, specular, and AO.
  auto colorCtx = ColorContext(elementColors, pixelCoords);
  if (intersect.accept) {
    // Locate the hit atom.
//    uint hitAtomID = largeAtomReferences[intersect.atomID];
    
    // Compute the hit point.
    float4 hitAtom = float4(convertedAtoms[intersect.atomID]);
    hitAtom.w = originalAtoms[largeAtomReferences[intersect.atomID]].w;
    hitAtom.xyz += float3(intersect.largeCellID) * 2 - 64;
    float3 hitPoint = primaryRayOrigin + intersect.distance * primaryRayDirection;
    half3 hitNormal = half3(normalize(hitPoint - hitAtom.xyz));
    
    // Set the diffuse color.
    colorCtx.setDiffuseColor(ushort(hitAtom[3]));
    
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
    GenerationContext generationContext(cameraArgs,
                                        renderArgs,
                                        pixelCoords);
    
    // Iterate over the AO samples.
    for (half i = 0; i < sampleCount; ++i) {
      // Spawn a secondary ray.
      float3 secondaryRayOrigin = hitPoint + 1e-4 * float3(hitNormal);
      float3 secondaryRayDirection = generationContext
        .secondaryRayDirection(i, sampleCount, hitPoint, hitNormal);
      
      // Intersect the secondary ray.
      IntersectionQuery query;
      query.isAORay = true;
      query.rayOrigin = secondaryRayOrigin;
      query.rayDirection = secondaryRayDirection;
      auto intersect = rayIntersector.intersect(query);
      
      // Add the secondary ray's AO contributions.
      ushort atomicNumber;
      if (intersect.accept) {
        uint atomID = largeAtomReferences[intersect.atomID];
        float4 atom = originalAtoms[atomID];
        atomicNumber = ushort(atom[3]);
      } else {
        atomicNumber = 0;
      }
      colorCtx.addAmbientContribution(atomicNumber, intersect.distance);
    }
    
    // Tell the context how many AO samples were taken.
    colorCtx.finishAmbientContributions(sampleCount);
    
    // Apply the camera position.
    colorCtx.startLightContributions();
    colorCtx.addLightContribution(hitPoint,
                                  hitNormal,
                                  cameraArgs->position);
    colorCtx.applyContributions();
    
    // Write the depth as the intersection point's Z coordinate.
    {
      float3 rayDirection = primaryRayDirection;
      float3 cameraDirection = cameraArgs->rotationColumn3;
      float rayDirectionComponent = dot(rayDirection, cameraDirection);
      float depth = rayDirectionComponent * intersect.distance;
      colorCtx.setDepth(depth);
    }
    
    // Generate the pixel motion vector.
    {
      half3 motionVector = atomMetadata[largeAtomReferences[intersect.atomID]];
      float3 previousHitPoint = hitPoint - float3(motionVector);
      colorCtx.generateMotionVector(cameraArgs + 1,
                                    renderArgs,
                                    previousHitPoint);
    }
  }
  colorCtx.write(colorTexture, depthTexture, motionTexture);
}
