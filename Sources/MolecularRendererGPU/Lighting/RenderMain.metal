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

class RayTracing {
public:
  METAL_FUNC static IntersectionResult traverse
  (
   Ray ray, DenseGrid grid, IntersectionParams params)
  {
    DifferentialAnalyzer dda(ray, grid);
    IntersectionResult result { MAXFLOAT, false };
    REFERENCE result_atom;
    
    float maxTargetDistance;
    if (params.isAORay || params.isShadowRay) {
      const float voxel_size = voxel_width_numer / voxel_width_denom;
      maxTargetDistance = params.maxRayHitTime + sqrt(float(3)) * voxel_size;
    }
    
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
      if ((params.isAORay || params.isShadowRay) &&
          (target_distance > maxTargetDistance)) {
        dda.continue_loop = false;
      } else {
        if (params.isShadowRay) {
          target_distance = min(target_distance, params.maxRayHitTime);
        }
        result.distance = target_distance;
        
#if FAULT_COUNTERS_ENABLE
        int fault_counter2 = 0;
#endif
        for (ushort i = 0; i < count; ++i) {
#if FAULT_COUNTERS_ENABLE
          fault_counter2 += 1; if (fault_counter2 > 300) { return { MAXFLOAT, false }; }
#endif
          REFERENCE reference = grid.references[offset + i];
          float4 data = ((device float4*)grid.atoms)[reference];
          
          // Do not walk inside an atom; doing so will produce corrupted graphics.
          float3 oc = ray.origin - data.xyz;
          float b2 = dot(oc, ray.direction);
          float c = dot(oc, oc) - as_type<half2>(data.w)[0];
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
    }
    
    if (result.accept) {
      result.atom = MRAtom(grid.atoms + result_atom);
    }
    return result;
  }
};

kernel void renderMain
 (
  constant Arguments *args [[buffer(0)]],
  constant MRAtomStyle *styles [[buffer(1)]],
  constant MRLight *lights [[buffer(2)]],
  
  device MRAtom *atoms [[buffer(3)]],
  device uint *dense_grid_data [[buffer(4)]],
  device REFERENCE *dense_grid_references [[buffer(5)]],
  
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
    
    // Cast the secondary rays.
    if (args->sampleCount > 0) {
      ushort samples = args->sampleCount;
      ushort effectiveSamples = args->sampleCount;
      half interpolationProgress = 0;
      
      // TODO: Move the docs, code, and mathematical proof into "GenerationContext".
      //
      // If you're very far away from the user, there's little benefit to
      // getting high-quality AO samples. This is also where AO rays become
      // heavily divergent (very expensive).
      constexpr float coefficient = 30;
#if HIGH_QUALITY_LARGE_SCENES
      constexpr ushort effectiveSamplesCutoff = 3;
#else
      constexpr ushort effectiveSamplesCutoff = 4;
#endif
      float distanceCutoff = coefficient / float(args->sampleCount);
      
      if (intersect.distance > distanceCutoff) {
        float proportion = distanceCutoff / intersect.distance;
        float newSamples = float(samples) * proportion;
        
#if HIGH_QUALITY_LARGE_SCENES
        newSamples = max(float(3), newSamples);
#else
        constexpr float linearizationCutoff = 3;
        if (newSamples <= linearizationCutoff) {
          // samples = 0;
          effectiveSamples = effectiveSamplesCutoff;
          
          // Linearize so this quickly reaches zero.
          //
          // coefficient = distanceCutoff * sampleCount;
          // f(x) = coefficient / x
          // d/dx (coefficient / x) = -coefficient / x^2
          //
          // f'(coefficient / 2) = -coefficient / (coefficient / 2)^2
          // f'(coefficient / 2) = -4 / coefficient
          //
          // L(f) = f(coeff / 2) + f'(coeff / 2) * (x - coeff / 2)
          // L(f) = 2 - 4 / coeff * (x - coeff / 2)
          //
          //     L(x') = 0
          //     L(x') = 2 - 4 / coeff * (x' - coeff / 2) = 0
          //         2 = 4 / coeff * (x' - coeff / 2)
          // coeff / 2 = x - coeff / 2
          //     coeff = x
          //
          float coeff = coefficient;
          float cutoff = linearizationCutoff;
          float L_f = intersect.distance - coeff / cutoff;
          L_f *= cutoff * cutoff / coeff;
          L_f = cutoff - L_f;
          newSamples = max(float(0), L_f);
        }
#endif
        
        float roundedSamples = ceil(newSamples);
        samples = ushort(roundedSamples);
        samples = min(samples, args->sampleCount);
        
        if (samples <= effectiveSamplesCutoff) {
          interpolationProgress = roundedSamples - newSamples;
          effectiveSamples = effectiveSamplesCutoff;
        } else {
          interpolationProgress = 0;
          effectiveSamples = samples;
        }
      }
      
      auto genCtx = GenerationContext(args, pixelCoords, hitPoint, normal);
      for (ushort i = 0; i < samples; ++i) {
        auto ray = genCtx.generate(i, samples);
        IntersectionParams params { true, args->maxRayHitTime, false };
        auto intersect = RayTracing::traverse(ray, grid, params);
        
        half progress = (i == samples - 1) ? interpolationProgress : 0;
        colorCtx.addAmbientContribution(intersect, progress);
      }
      for (ushort i = samples; i < effectiveSamples; ++i) {
        IntersectionResult intersect { MAXFLOAT, false };
        colorCtx.addAmbientContribution(intersect, 0);
      }
      colorCtx.finishAmbientContributions(effectiveSamples);
    }
    
    for (ushort i = 0; i < args->numLights; ++i) {
      MRLight light(lights + i);
      bool shadow = false;
      
      ushort cameraFlag = as_type<ushort>(light.diffusePower) & 0x1;
      if (cameraFlag) {
        // This is a camera light.
      } else {
        // Cast a shadow ray.
        float3 direction = light.origin - hitPoint;
        float distance_sq = length_squared(direction);
        direction *= rsqrt(distance_sq);
        
        Ray ray { hitPoint + 0.0001 * normal, direction };
        IntersectionParams params { false, sqrt(distance_sq), true };
        
        auto intersect = RayTracing::traverse(ray, grid, params);
        if (intersect.accept) {
          shadow = true;
        }
      }
      if (!shadow) {
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
