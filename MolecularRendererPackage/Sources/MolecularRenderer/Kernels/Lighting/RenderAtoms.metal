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
#include "../Uniform Grids/DDA.metal"
using namespace metal;

kernel void renderAtoms
(
 const device Arguments *args [[buffer(0)]],
 const device float3 *atomColors [[buffer(1)]],
 
 device uint *dense_grid_data [[buffer(4)]],
 device uint *dense_grid_references [[buffer(5)]],
 
 device float3 *motion_vectors [[buffer(6)]],
 device float4 *newAtoms [[buffer(10)]],
 
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
    args->world_origin,
    args->world_dims,
    dense_grid_data,
    dense_grid_references,
    newAtoms
  };
  
  // Cast the primary ray.
  auto ray = RayGeneration::primaryRay(pixelCoords, args);
  IntersectionParams params { false, MAXFLOAT, false };
  auto intersect = RayIntersector::traverse(ray, grid, params);
  
  // Calculate ambient occlusion, diffuse, and specular terms.
  auto colorCtx = ColorContext(args, atomColors, pixelCoords);
  if (intersect.accept) {
    float3 hitPoint = ray.origin + ray.direction * intersect.distance;
    half3 normal = half3(normalize(hitPoint - intersect.newAtom.xyz));
    colorCtx.setDiffuseColor(intersect.newAtom);
    
    // Cast the secondary rays.
    {
      constexpr half minSamples = 3.0;
      constexpr half maxSamples = 7.0;
      
      half samples = maxSamples;
      float distanceCutoff = args->qualityCoefficient / maxSamples;
      if (intersect.distance > distanceCutoff) {
        half proportion = distanceCutoff / intersect.distance;
        half newSamples = max(minSamples, samples * proportion);
        samples = clamp(ceil(newSamples), minSamples, maxSamples);
      }
      
      auto genCtx = GenerationContext(args, pixelCoords);
      for (half i = 0; i < samples; ++i) {
        auto ray = genCtx.generate(i, samples, hitPoint, normal);
        IntersectionParams params { true, MAX_RAY_HIT_TIME, false };
        auto intersect = RayIntersector::traverse(ray, grid, params);
        colorCtx.addAmbientContribution(intersect);
      }
      colorCtx.finishAmbientContributions(samples);
    }
    
    colorCtx.startLightContributions();
    colorCtx.addLightContribution(hitPoint, normal, args->position);
    colorCtx.applyContributions();
    
    // Write the depth as the intersection point's Z coordinate.
    float depth = ray.direction.z * intersect.distance;
    colorCtx.setDepth(depth);
    float3 motionVector = motion_vectors[intersect.reference];
    colorCtx.generateMotionVector(hitPoint - motionVector);
  }
  colorCtx.write(color_texture, depth_texture, motion_texture);
}
