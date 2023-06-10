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
      
      // Align the atoms' coordinate systems with each other, to minimize
      // divergence. Here is a primitive method that achieves that by aligning
      // the X and Y dimensions to a common coordinate space.
      float3 modNormal = transpose(args->cameraToWorldRotation) * normal;
      float3x3 axes = RayGeneration::makeBasis(modNormal);
      axes = args->cameraToWorldRotation * axes;
#if 0
      float3 modNormalSum = {
        simd_sum(modNormal.x),
        simd_sum(modNormal.y),
        simd_sum(modNormal.z)
      };
      float modNormalSum_len_sq = length_squared(modNormalSum);
      if (modNormalSum_len_sq > 1e-6) {
        modNormalSum *= rsqrt(modNormalSum_len_sq);
      } else {
        modNormalSum = float3(0, 1, 0);
      }
      
      // I don't know why, but transposing the basis changed it from something
      // that consistently harmed performance, to not affecting performance. I
      // need to understand why this happened before applying the optimization
      // that sorts rays in local space.
      float3x3 localToWorldTransform = RayGeneration::makeBasis(modNormalSum);
      float3x3 worldToLocalTransform = transpose(localToWorldTransform);
#endif
      
      uint pixelSeed = as_type<uint>(pixelCoords);
      uint seed = Sampling::tea(pixelSeed, args->frameSeed);
      
      for (ushort i = 0; i < RTAO_SAMPLES; ++i) {
        // Generate a random number and increment the seed.
        float random1 = Sampling::radinv3(seed);
        float random2 = Sampling::radinv2(seed);
        seed += 1;
       
        float minimum = i / float(RTAO_SAMPLES);
        float maximum = minimum + 1 / float(RTAO_SAMPLES);
        maximum = (i == RTAO_SAMPLES - 1) ? 1 : maximum;
        random1 = mix(minimum, maximum, random1);
        
        // Create a random ray from the cosine distribution.
        RayGeneration::Basis basis { axes, random1, random2 };
        ray ray2 = RayGeneration::secondaryRay(origin, basis);
        ray2.max_distance = args->maxRayHitTime;
        
        // Cast the secondary ray.
        auto intersect2 = RayTracing::traverse(ray2, accel);
        
        float diffuseAmbient = 1;
        float specularAmbient = 1;
        if (intersect2.accept) {
          float t = intersect2.distance / args->maxRayHitTime;
          float lambda = args->exponentialFalloffDecayConstant;
          float occlusion = exp(-lambda * t * t);
          diffuseAmbient -= (1 - args->minimumAmbientIllumination) * occlusion;
          
          // Diffuse interreflectance should affect the final diffuse term, but
          // not the final specular term.
          specularAmbient = diffuseAmbient;
          
          constexpr half3 gamut(0.212671, 0.715160, 0.072169); // sRGB/Rec.709
          float luminance = dot(colorCtx.getDiffuseColor(), gamut);
          
          // Account for the color of the occluding atom. This decreases the
          // contrast between differing elements placed near each other. It also
          // makes the effect vary around the atom's surface.
          half3 neighborColor = intersect2.atom.getColor(atomData);
          float neighborLuminance = dot(neighborColor, gamut);

          // Use the arithmetic mean. There is no perceivable difference from
          // the (presumably more accurate) geometric mean.
          luminance = (luminance + neighborLuminance) / 2;
          
          float kA = diffuseAmbient;
          float rho = args->diffuseReflectanceScale * luminance;
          diffuseAmbient = kA / (1 - rho * (1 - kA));
        }
        
        colorCtx.addAmbientContribution(diffuseAmbient, specularAmbient);
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
