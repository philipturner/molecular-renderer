//
//  RenderMain.metal
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

kernel void renderMain
 (
  constant Arguments *args [[buffer(0)]],
  constant MRAtomStyle *styles [[buffer(1)]],
  constant MRLight *lights [[buffer(2)]],
  
  device MRAtom *atoms [[buffer(3)]],
  device uint *dense_grid_data [[buffer(4)]],
  device ushort *dense_grid_references [[buffer(5)]],
  
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
  DenseGrid grid(args->grid_width, dense_grid_data,
                 dense_grid_references, atoms);
  
  // Cast the primary ray.
  auto ray = RayGeneration::primaryRay(pixelCoords, args);
  IntersectionParams params { false, MAXFLOAT, false };
  auto intersect = RayTracing::traverse(ray, grid, params);
  
  // Calculate specular, diffuse, and ambient occlusion.
  auto colorCtx = ColorContext(args, styles, pixelCoords);
  if (intersect.accept) {
    float3 hitPoint = ray.origin + ray.direction * intersect.distance;
    float3 normal = normalize(hitPoint - intersect.atom.origin);
    colorCtx.setDiffuseColor(intersect.atom, normal);
    
    // TODO: Support analytical occlusion as a cheaper, but lower-quality option
    // on smaller GPUs. It should be combined with a reduced but nonzero number
    // of long-distance ray samples, making it "hybrid ray tracing" (maybe).
    //
    // Create a second uniform grid storing non-duplicated references to the
    // centers of spheres. It should have 2x linear/8x spatial resolution. Poll
    // all the voxels within a certain radius, rejecting spheres that fall
    // outside the radius.
    if (args->sampleCount > 0) {
      auto genCtx = GenerationContext(args, pixelCoords, hitPoint, normal);
      for (ushort i = 0; i < args->sampleCount; ++i) {
        // Cast the secondary ray.
        auto ray = genCtx.generate(i);
        IntersectionParams params { true, args->maxRayHitTime, false };
        auto intersect = RayTracing::traverse(ray, grid, params);
        colorCtx.addAmbientContribution(intersect);
      }
    }
    
    colorCtx.setLightingConditions(args);
    for (ushort i = 0; i < args->numLights; ++i) {
      MRLight light(lights + i);
      bool shadow = false;
      if (light.flags & 0x1) {
        // This is a camera light.
      } else {
        // Cast a shadow ray.
        float3 direction = light.origin - hitPoint;
        float distance_sq = length_squared(direction);
        direction *= rsqrt(distance_sq);
        
        Ray ray { hitPoint + 0.001 * direction, direction };
        IntersectionParams params { false, sqrt(distance_sq), true };
        
        auto intersect = RayTracing::traverse(ray, grid, params);
        if (intersect.accept) {
          shadow = true;
        }
      }
      if (!shadow) {
        // TODO: Avoid adding specular contributions from this light. However,
        // we shouldn't entirely suppress the diffuse contributions.
        colorCtx.addLightContribution(hitPoint, normal, light);
      }
    }
    colorCtx.applyContributions();
    
    // Write the depth as the intersection point's Z coordinate.
    float depth = ray.direction.z * intersect.distance;
    colorCtx.setDepth(depth);
    colorCtx.generateMotionVector(hitPoint);
  }
  
  colorCtx.write(color_texture, depth_texture, motion_texture);
}
