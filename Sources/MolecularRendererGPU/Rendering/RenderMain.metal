//
//  RenderMain.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
#include "Constants.metal"
#include "Lighting.metal"
#include "RayTracing.metal"
#include "RayGeneration.metal"
#include "UniformGrid.metal"
using namespace metal;

kernel void renderMain
 (
  constant Arguments *args [[buffer(0)]],
  constant MRAtomStyle *styles [[buffer(1)]],
  
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
  auto intersect = RayTracing::traverseDenseGrid(ray, grid);
  
  // Calculate specular, diffuse, and ambient occlusion.
  auto colorCtx = ColorContext(args, styles, pixelCoords);
  if (intersect.accept) {
    float3 hitPoint = ray.origin + ray.direction * intersect.distance;
    float3 normal = normalize(hitPoint - intersect.atom.origin);
    colorCtx.setDiffuseColor(intersect.atom, normal);
    
    if (args->sampleCount > 0) {
      auto genCtx = GenerationContext(args, pixelCoords, hitPoint, normal);
      for (ushort i = 0; i < args->sampleCount; ++i) {
        // Cast the secondary ray.
        auto ray = genCtx.generate(i);
        auto intersect = RayTracing::traverseDenseGrid(ray, grid);
        colorCtx.addAmbientContribution(intersect);
      }
    }
    colorCtx.setLightContributions(hitPoint, normal);
    colorCtx.applyLightContributions();
    
    // Write the depth as the intersection point's Z coordinate.
    float depth = ray.direction.z * intersect.distance;
    colorCtx.setDepth(depth);
    colorCtx.generateMotionVector(hitPoint);
  }
  
  colorCtx.write(color_texture, depth_texture, motion_texture);
}
