//
//  RenderAtoms.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "../Lighting/Lighting.metal"
#include "../Ray Tracing/RayTracing.metal"
#include "../Ray Tracing/RayGeneration.metal"
#include "../Uniform Grids/UniformGrid.metal"
using namespace metal;

constant bool not_offline = !OFFLINE;

kernel void renderAtoms
(
 const device Arguments *args [[buffer(0)]],
 const device MRAtomStyle *styles [[buffer(1)]],
 device MRLight *lights [[buffer(2)]],
 
 device MRAtom *atoms [[buffer(3)]],
 device VOXEL_DATA *dense_grid_data [[buffer(4)]],
 device uint *dense_grid_references [[buffer(5)]],
 
 device float3 *motion_vectors [[buffer(6)]],
 
 texture2d<half, access::write> color_texture [[texture(0)]],
 texture2d<float, access::write> depth_texture [[
   texture(1), function_constant(not_offline)]],
 texture2d<half, access::write> motion_texture [[
   texture(2), function_constant(not_offline)]],
 
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
    args->world_dims,
    dense_grid_data,
    dense_grid_references,
    atoms
  };
  
  // Cast the primary ray.
  auto ray = RayGeneration::primaryRay(pixelCoords, args);
  IntersectionParams params { false, MAXFLOAT, false };
  auto intersect = RayIntersector::traverse(ray, grid, params);
  
  // Calculate ambient occlusion, diffuse, and specular terms.
  auto colorCtx = ColorContext(args, styles, pixelCoords);
  if (intersect.accept) {
    float3 hitPoint = ray.origin + ray.direction * intersect.distance;
    half3 normal = half3(normalize(hitPoint - intersect.atom.origin));
    colorCtx.setDiffuseColor(intersect.atom, normal);
    
    // Cast the secondary rays.
    half minSamples = args->minSamples;
    half maxSamples = args->maxSamples;
    if (maxSamples > 0) {
      half samples = args->maxSamples;
      float distanceCutoff = args->qualityCoefficient / maxSamples;
      if (intersect.distance > distanceCutoff) {
        half proportion = distanceCutoff / intersect.distance;
        half newSamples = max(minSamples, samples * proportion);
        samples = clamp(ceil(newSamples), minSamples, maxSamples);
      }
      
      auto genCtx = GenerationContext(args, pixelCoords);
      for (half i = 0; i < samples; ++i) {
        auto ray = genCtx.generate(i, samples, hitPoint, normal);
        IntersectionParams params { true, args->maxRayHitTime, false };
        auto intersect = RayIntersector::traverse(ray, grid, params);
        colorCtx.addAmbientContribution(intersect);
      }
      colorCtx.finishAmbientContributions(samples);
    }
    
    colorCtx.startLightContributions();
    ushort numLights = args->numLights;
    for (ushort i = 0; i < numLights; ++i) {
      MRLight light(lights + i);
      half hitAtomRadiusSquared = 0;
      
      ushort cameraFlag = as_type<ushort>(light.diffusePower) & 0x1;
      if (cameraFlag) {
        // This is a camera light.
      } else {
        // Cast a shadow ray.
        float3 direction = light.origin - hitPoint;
        float distance_sq = length_squared(direction);
        direction *= rsqrt(distance_sq);
        
        Ray<float> ray { hitPoint + 0.0001 * float3(normal), direction };
        IntersectionParams params { false, 0.3 + sqrt(distance_sq), true };
        auto intersect = RayIntersector::traverse(ray, grid, params);
        if (intersect.accept) {
          hitAtomRadiusSquared = intersect.atom.radiusSquared;
        }
      }
      if (hitAtomRadiusSquared == 0) {
        colorCtx.addLightContribution(hitPoint, normal, light);
      }
    }
    colorCtx.applyContributions();
    
    // Write the depth as the intersection point's Z coordinate.
    float depth = ray.direction.z * intersect.distance;
    colorCtx.setDepth(depth);
    float3 motionVector = motion_vectors[intersect.reference];
    colorCtx.generateMotionVector(hitPoint - motionVector);
  }
  if (OFFLINE) {
    colorCtx.write_offline(color_texture);
  } else {
    colorCtx.write(color_texture, depth_texture, motion_texture);
  }
}
