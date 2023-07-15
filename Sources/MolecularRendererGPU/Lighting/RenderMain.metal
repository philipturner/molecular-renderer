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
  template <typename T>
  METAL_FUNC static IntersectionResult traverse
  (
   Ray<T> ray, DenseGrid grid, IntersectionParams params)
  {
    DifferentialAnalyzer<T> dda(ray, grid.width);
    IntersectionResult result { MAXFLOAT, false };
    REFERENCE result_atom;
    
    float maxTargetDistance;
    if (params.isAORay || params.isShadowRay) {
      const float voxel_size = voxel_width_numer / voxel_width_denom;
      maxTargetDistance = params.maxRayHitTime + sqrt(float(3)) * voxel_size;
    }
    
    while (dda.continue_loop) {
      // To reduce divergence, fast forward through empty voxels.
      uint voxel_data = 0;
      bool continue_fast_forward = true;
      while (continue_fast_forward) {
        voxel_data = grid.data[dda.address];
        dda.increment_position();
        
        float target_distance = dda.get_max_accepted_t();
        if ((params.isAORay || params.isShadowRay) &&
            (target_distance > maxTargetDistance)) {
          dda.continue_loop = false;
        }
        
        if ((voxel_data & voxel_count_mask) == 0) {
          continue_fast_forward = dda.continue_loop;
        } else {
          continue_fast_forward = false;
        }
      }
      
      float target_distance = dda.get_max_accepted_t();
      if ((params.isAORay || params.isShadowRay) &&
          (target_distance > maxTargetDistance)) {
        dda.continue_loop = false;
      } else {
        if (params.isShadowRay) {
          target_distance = min(target_distance, params.maxRayHitTime);
        }
        result.distance = target_distance;
        
        uint count = reverse_bits(voxel_data & voxel_count_mask);
        uint offset = voxel_data & voxel_offset_mask;
        uint upper_bound = offset + count;
        for (; offset < upper_bound; ++offset) {
          REFERENCE reference = grid.references[offset];
          float4 data = ((device float4*)grid.atoms)[reference];
          
          // Do not walk inside an atom; doing so will produce corrupted graphics.
          float3 oc = ray.origin - data.xyz;
          float b2 = dot(oc, float3(ray.direction));
          float c = fma(oc.x, oc.x, float(-as_type<half2>(data.w)[0]));
          c = fma(oc.y, oc.y, c);
          c = fma(oc.z, oc.z, c);
          
          float disc4 = b2 * b2 - c;
          if (disc4 > 0) {
            // If the ray hit the sphere, compute the intersection distance.
            float distance = fma(-disc4, rsqrt(disc4), -b2);
            
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
 device Arguments *args [[buffer(0)]],
 device MRAtomStyle *styles [[buffer(1)]],
 device MRLight *lights [[buffer(2)]],
 
 device MRAtom *atoms [[buffer(3)]],
 device uint *dense_grid_data [[buffer(4)]],
 device REFERENCE *dense_grid_references [[buffer(5)]],
 
 device float *profiling_samples [[buffer(6)]],
 
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
  
  // Initialize the profiling sample.
  half sampleValue = 0;
  half sampleSize = 0;
  
  // Calculate ambient occlusion, diffuse, and specular terms.
  auto colorCtx = ColorContext(args, styles, pixelCoords);
  if (intersect.accept) {
    sampleValue = quad_max(float(intersect.atom.radiusSquared));
    sampleSize = 1;
    
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
        auto intersect = RayTracing::traverse(ray, grid, params);
        colorCtx.addAmbientContribution(intersect);
        
        float atomRsq = 0;
        if (intersect.accept) {
          atomRsq = float(intersect.atom.radiusSquared);
        }
        atomRsq = quad_max(atomRsq);
        if (atomRsq > 0) {
          sampleValue += atomRsq;
          sampleSize += 1;
        }
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
        IntersectionParams params { false, sqrt(distance_sq), true };
        auto intersect = RayTracing::traverse(ray, grid, params);
        if (intersect.accept) {
          hitAtomRadiusSquared = intersect.atom.radiusSquared;
        }
      }
      if (hitAtomRadiusSquared == 0) {
        colorCtx.addLightContribution(hitPoint, normal, light);
      }
      
      float atomRsq = quad_max(float(hitAtomRadiusSquared));
      if (atomRsq > 0) {
        sampleValue += atomRsq;
        sampleSize += 1;
      }
    }
    colorCtx.applyContributions();
    
    // Write the depth as the intersection point's Z coordinate.
    float depth = ray.direction.z * intersect.distance;
    colorCtx.setDepth(depth);
    colorCtx.generateMotionVector(hitPoint);
  }
  colorCtx.write(color_texture, depth_texture, motion_texture);
  
  // Store the profiling sample.
  float2 sample(sampleValue, sampleSize);
  sample += simd_shuffle_xor(sample, 4);
  sample += simd_shuffle_xor(sample, 8);
  sample += simd_shuffle_xor(sample, 16);
  
  if (simd_is_first()) {
    ushort2 coords = pixelCoords / ushort2(8, 4);
    ushort sampleRows = (SCREEN_WIDTH + 7) / 8;
    ushort sampleCols = (SCREEN_HEIGHT + 3) / 4;
    uint valueIndex = uint(coords.y * sampleRows) + coords.x;
    profiling_samples[valueIndex] = sample[0];
    
    uint countIndex = valueIndex + uint(sampleRows * sampleCols);
    profiling_samples[countIndex] = sample[1];
  }
}
