//
//  RenderMain.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
#include "AtomStatistics.metal"
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

  // Cast initial ray.
  ray ray = RayGeneration::primaryRay(pixelCoords, args);
  auto intersect = RayTracing::traverse(ray, accel);
  
  // Create a default color for the background.
  auto colorCtx = ColorContext();
//  half3 color = { 0.707, 0.707, 0.707 };
//  half2 motionVector = 0;
//  float depth = -FLT_MAX;
  
  // Calculate specular, diffuse, and ambient occlusion.
  if (intersect.accept) {
    Atom atom = intersect.atom;
//    constexpr float shininess = 16.0;
//    constexpr float lightPower = 40.0;
//
//    // Base color of the sphere.
//    half3 diffuseColor;
//    if (atom.flags & 0x2) {
//      // Replace the diffuse color with black.
//      diffuseColor = { 0.000, 0.000, 0.000 };
//    } else {
//      diffuseColor = atom.getColor(atomData);
//    }
    
    // TODO: Rename to 'hitPoint'.
    float3 intersectionPoint = ray.origin + ray.direction * intersect.distance;
    colorCtx.setIntersection(atom, intersectionPoint);
    colorCtx.setDiffuse(atomData);
    colorCtx.setLightContributions(args);
    
//    // Apply checkerboard to tagged atoms.
//    if (atom.flags & 0x1) {
//      // Determine whether the axes are positive.
//      float3 delta = intersectionPoint - atom.origin;
//      bool3 axes_pos = delta > 0;
//      bool is_magenta = axes_pos.x ^ axes_pos.y ^ axes_pos.z;
//
//      half3 magenta(252.0 / 255, 0.0 / 255, 255.0 / 255);
//      diffuseColor = is_magenta ? magenta : diffuseColor;
//    }
//
//    // From https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model:
//    float3 normal = normalize(intersectionPoint - intersect.atom.origin);
//    float3 lightDirection = args->position - intersectionPoint;
//    float lightDistance = length(lightDirection);
//    lightDirection /= lightDistance;
    
//    float lambertian = max(dot(lightDirection, normal), 0.0);
//    float specular = 0;
//    if (lambertian > 0.0) {
//      // 'halfDir' equals 'viewDir' equals 'lightDir' in this case.
//      float specAngle = lambertian;
//      specular = pow(specAngle, shininess);
//    }
//
//    // TODO: The specular part looks very strange for colors besides gray.
//    // Determine what QuteMol does to fix this.
//    float scaledLightPower = smoothstep(0, 1, lightPower / lightDistance);
//    float3 out = float3(diffuseColor) * lambertian * scaledLightPower;
//    out += specular * scaledLightPower;
    float occlusion = 0;
    if (USE_RTAO) {
//       TODO: Do you apply occlusion before or after the specular part?
      occlusion = RayGeneration::queryOcclusion
       (
        intersectionPoint, atom, pixelCoords, args->frameSeed,
        accel);
//      out *= occlusion;
    }
    colorCtx.setOcclusion(occlusion);
    colorCtx.applyContributions();
//    color = half3(saturate(out));
    
    if (USE_METALFX) {
//      float3 direction = normalize(intersectionPoint - args[1].position);
//      direction = transpose(args[1].rotation) * direction;
//      direction *= args[1].fov90Span / direction.z;
//
      // Write the depth as the intersection point's Z coordinate.
      float depth = ray.direction.z * intersect.distance;
      colorCtx.setDepth(depth);
      colorCtx.generateMotionVector(args, pixelCoords);
//
//      // I have no idea why, but the X coordinate is flipped here.
//      float2 prevCoords = direction.xy;
//      prevCoords.x = -prevCoords.x;
//
//      // Recompute the current pixel coordinates (do not waste registers).
//      float2 currCoords = float2(pixelCoords) + 0.5;
//      currCoords.xy -= float2(SCREEN_WIDTH, SCREEN_HEIGHT) / 2;
//
//      // Generate the motion vector from pixel coordinates.
//      motionVector = half2(currCoords - prevCoords);
//
//      // I have no idea why, but the Y coordinate is flipped here.
//      motionVector.y = -motionVector.y;
    }
  }
  
  colorCtx.write(colorTexture, depthTexture, motionTexture, pixelCoords);
  
//  // Write the output color.
//  colorTexture.write(half4(color, 1), pixelCoords);
//
//  if (USE_METALFX) {
//    // Write the output depth.
//    depth = 1 / float(1 - depth); // map (0, -infty) to (1, 0)
//    depthTexture.write(float4{ depth }, pixelCoords);
//
//    // Write the output motion vectors.
//    motionVector = clamp(motionVector, -HALF_MAX, HALF_MAX);
//    motionTexture.write(half4{ motionVector.x, motionVector.y }, pixelCoords);
//  }
}
