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
using namespace raytracing;

kernel void renderMain
 (
  constant Arguments *args [[buffer(0)]],
  constant MRAtomStyle *styles [[buffer(1)]],
  accel accel [[buffer(2)]],
  
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
  ray ray = RayGeneration::primaryRay(pixelCoords, args);
  IntersectionResult intersect;
//  if (args->use_uniform_grid && pixelCoords.x >= 320) {
    intersect = RayTracing::traverse_dense_grid(ray, grid);
//  } else {
//    intersect = RayTracing::traverse(ray, accel);
//  }
  
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
        IntersectionResult intersect;
        
//        if (args->use_uniform_grid && pixelCoords.x >= 320) {
          intersect = RayTracing::traverse_dense_grid(ray, grid);
//        } else {
//          intersect = RayTracing::traverse(ray, accel);
//        }
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

// MARK: - Temporary Implementation of RayTracing::traverse_dense_grid

IntersectionResult RayTracing::traverse_dense_grid
(
 const ray ray, const DenseGrid const_grid)
{
  DenseGrid grid = const_grid;
  DifferentialAnalyzer dda(ray, grid);
  IntersectionResult result { MAXFLOAT, false };
  ushort result_atom;
  
#if FAULT_COUNTERS_ENABLE
  int fault_counter1 = 0;
#endif
  while (dda.continue_loop) {
    // To reduce divergence, fast forward through empty voxels.
    uint voxel_data = 0;
    bool continue_fast_forward = true;
    while (continue_fast_forward) {
#if FAULT_COUNTERS_ENABLE
      fault_counter1 += 1; if (fault_counter1 > 100) { return { MAXFLOAT, false }; }
#endif
      voxel_data = grid.data[dda.address];
      dda.increment_position();
      
      if ((voxel_data & voxel_count_mask) == 0) {
        continue_fast_forward = dda.continue_loop;
      } else {
        continue_fast_forward = false;
      }
    }
    
    uint count = reverse_bits(voxel_data & voxel_count_mask);
    uint offset = voxel_data & voxel_offset_mask;
    
    float target_distance = dda.get_max_accepted_t();
    result.distance = target_distance;
    
#if FAULT_COUNTERS_ENABLE
    int fault_counter2 = 0;
#endif
    for (ushort i = 0; i < count; ++i) {
#if FAULT_COUNTERS_ENABLE
      fault_counter2 += 1; if (fault_counter2 > 300) { return { MAXFLOAT, false }; }
#endif
      // TODO: Force references to be aligned to multiples of 2, even if you duplicate references.
      // The atom with offset COUNT-1 will write to the end of the region.
      ushort reference = grid.references[offset + i];
      MRAtom atom = grid.atoms[reference];
      
      // Do not walk inside an atom; doing so will produce corrupted graphics.
      float3 oc = ray.origin - atom.origin;
      float b2 = dot(oc, ray.direction);
      float c = dot(oc, oc) - atom.radiusSquared;
      float disc4 = b2 * b2 - c;
      
      if (disc4 > 0) {
        // If the ray hit the sphere, compute the intersection distance.
        float distance = -b2 - sqrt(disc4);
        
        // The intersection function must also check whether the intersection
        // distance is within the acceptable range. Intersection functions do not
        // run in any particular order, so the maximum distance may be different
        // from the one passed into the ray intersector.
        if (distance >= 0 && distance < result.distance) {
          result.distance = distance;
          result_atom = reference;
        }
      }
    }
    if (result.distance < target_distance) {
      result.accept = true;
      dda.continue_loop = false;
    }
  }
  
  if (result.accept) {
    result.atom = grid.atoms[result_atom];
  }
  return result;
}
