//
//  RenderAtoms.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
#include "Utilities/Constants.metal"
#include "Lighting/Lighting.metal"
#include "Ray Tracing/RayTracing.metal"
#include "Ray Tracing/RayGeneration.metal"
#include "Uniform Grids/DDA.metal"
using namespace metal;

kernel void renderAtoms
(
 constant CameraArguments *cameraArgs [[buffer(0)]],
 constant BVHArguments *bvhArgs [[buffer(1)]],
 constant RenderArguments *renderArgs [[buffer(2)]],
 
 device uint *dense_grid_data [[buffer(5)]],
 device uint *dense_grid_references [[buffer(6)]],
 
 device float4 *newAtoms [[buffer(10)]],
 device float3 *atomColors [[buffer(11)]],
 device float3 *motionVectors [[buffer(12)]],
 
 texture2d<half, access::write> color_texture [[texture(0)]],
 texture2d<float, access::write> depth_texture [[texture(1)]],
 texture2d<half, access::write> motion_texture [[texture(2)]],
 
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
    dense_grid_data,
    dense_grid_references,
    newAtoms
  };
  
  // Cast the primary ray.
  auto ray = RayGeneration::primaryRay(cameraArgs,
                                       renderArgs->jitter,
                                       pixelCoords);
  IntersectionParams params { false, MAXFLOAT, false };
  auto intersect = RayIntersector::traverse(ray, grid, params);
  
  // Calculate ambient occlusion, diffuse, and specular terms.
  auto colorCtx = ColorContext(atomColors, pixelCoords);
  if (intersect.accept) {
    float3 hitPoint = ray.origin + ray.direction * intersect.distance;
    half3 normal = half3(normalize(hitPoint - intersect.newAtom.xyz));
    colorCtx.setDiffuseColor(intersect.newAtom);
    
    // Cast the secondary rays.
    {
      constexpr half minSamples = 3.0;
      constexpr half maxSamples = 7.0;
      
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
        IntersectionParams params { true, MAX_RAY_HIT_TIME, false };
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
    
    // Transform to the atom's position in the previous frame.
    float3 motionVector;
    if (renderArgs->useMotionVectors) {
      motionVector = motionVectors[intersect.reference];
    } else {
      motionVector = float3(0);
    }
    colorCtx.generateMotionVector(cameraArgs + 1,
                                  hitPoint - motionVector);
  }
  colorCtx.write(color_texture, depth_texture, motion_texture);
}
