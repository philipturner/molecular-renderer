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
using namespace metal;
using namespace raytracing;

kernel void renderMain
 (
  constant Arguments *args [[buffer(0)]],
  constant AtomStatistics *atomData [[buffer(1)]],
  accel accel [[buffer(2)]],
  
  texture2d<half, access::write> colorTexture [[texture(0)]],
  texture2d<float, access::write> depthTexture [[texture(1), function_constant(USE_METALFX)]],
  texture2d<half, access::write> motionTexture [[texture(2), function_constant(USE_METALFX)]],
  
  ushort2 tid [[thread_position_in_grid]],
  ushort2 tgid [[threadgroup_position_in_grid]],
  ushort2 lid [[thread_position_in_threadgroup]])
{
  // Return early if outside bounds.
  ushort2 pixelCoords = RayGeneration::makePixelID(tgid, lid);
  if ((SCREEN_WIDTH % 16 != 0) && (pixelCoords.x >= SCREEN_WIDTH)) return;
  if ((SCREEN_HEIGHT % 16 != 0) && (pixelCoords.y >= SCREEN_HEIGHT)) return;

  // Cast the primary ray.
  ray ray1 = RayGeneration::primaryRay(pixelCoords, args);
  auto intersect1 = RayTracing::traverse(ray1, accel);
  
  // Calculate specular, diffuse, and ambient occlusion.
  auto colorCtx = ColorContext(args, atomData, pixelCoords);
  if (intersect1.accept) {
    float3 hitPoint = ray1.origin + ray1.direction * intersect1.distance;
    float3 normal = normalize(hitPoint - intersect1.atom.origin);
    colorCtx.setDiffuseColor(intersect1.atom, normal);
    
    if (USE_RTAO) {
      // Move origin slightly away from the surface to avoid self-occlusion.
      // Switching to a uniform grid acceleration structure should make it
      // possible to ignore this parameter.
      float3 origin = hitPoint + normal * float(0.001);
      float3x3 basis = RayGeneration::makeBasis(normal);
      uint pixelSeed = as_type<uint>(pixelCoords);
      uint seed = Sampling::tea(pixelSeed, args->frameSeed);
      
      for (ushort i = 0; i < RTAO_SAMPLES; ++i) {
        // Create a random ray from the cosine distribution.
        ray ray2 = RayGeneration::secondaryRay(origin, seed, basis);
        ray2.max_distance = args->maxAORayHitTime;
        seed += 1;
        
        // Cast the secondary ray.
        auto intersect2 = RayTracing::traverse(ray2, accel);
        
        float ambientCoef = 1;
        if (intersect2.accept) {
          float theoreticalTMax = args->maxTheoreticalAORayHitTime;
          float t = intersect2.distance / theoreticalTMax;
          float lambda = args->exponentialFalloffDecayConstant;
          float occlusionCoef = exp(-lambda * t * t);
          ambientCoef -= (1 - args->minimumAmbientIllumination) * occlusionCoef;
        }
        
        constexpr half3 gamut(0.212671, 0.715160, 0.072169); // sRGB/Rec.709
        float luminance = dot(colorCtx.getDiffuseColor(), gamut);
        {
#if 0
          // Account for color of occluding atom.
          half3 neighborColor = intersect2.atom.getColor(atomData);
          float neighborLuminance;
          if (intersect2.atom.element <= 200) {
            neighborLuminance = dot(neighborColor, gamut);
          } else {
            // Some kind of bug is corrupting the memory.
            neighborLuminance = INFINITY;
          }
          luminance = mix(luminance, neighborLuminance, 0.00000001);
#endif
        }
        float kA = ambientCoef;
        float rho = args->diffuseReflectanceScale * luminance;
        ambientCoef = kA / (1 - rho * (1 - kA));
        colorCtx.addAmbientContribution(ambientCoef);
      }
    }
    colorCtx.setLightContributions(hitPoint, normal);
    colorCtx.applyLightContributions();
    
    if (USE_METALFX) {
      // Write the depth as the intersection point's Z coordinate.
      float depth = ray1.direction.z * intersect1.distance;
      colorCtx.setDepth(depth);
      colorCtx.generateMotionVector(hitPoint);
    }
  }
  
  colorCtx.write(colorTexture, depthTexture, motionTexture);
}
