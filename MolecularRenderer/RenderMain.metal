//
//  RenderMain.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
#include "AtomStatistics.metal"
#include "RayTracing.metal"
using namespace metal;

constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];
constant float FOV_90_SPAN_RECIPROCAL [[function_constant(2)]];

// Dispatch threadgroups across 16x16 chunks, not rounded to image size.
// This shader will rearrange simds across 8x2 to 8x8 chunks (depending on the
// GPU architecture).
kernel void renderMain
 (
  texture2d<half, access::write> outputTexture [[texture(0)]],
  
  constant AtomStatistics *atomData [[buffer(0)]],
  device Atom *atoms [[buffer(1)]],
  ushort2 tid [[thread_position_in_grid]],
  ushort2 tgid [[threadgroup_position_in_grid]],
  ushort2 local_id [[thread_position_in_threadgroup]])
{
  ushort2 new_local_id = local_id;
  new_local_id.y *= 2;
  if (new_local_id.x % 16 >= 8) {
    new_local_id.y += 1;
    new_local_id.x -= 8;
  }
  if (new_local_id.y >= 16) {
    new_local_id.y -= 16;
    new_local_id.x += 8;
  }
  
  ushort2 pixelCoords = tgid * 16 + new_local_id;
  if (SCREEN_WIDTH % 16 != 0) {
    if (pixelCoords.x >= SCREEN_WIDTH) {
      return;
    }
  }
  if (SCREEN_HEIGHT % 16 != 0) {
    if (pixelCoords.y >= SCREEN_HEIGHT) {
      return;
    }
  }
  
  float3 rayDirection(float2(pixelCoords) + 0.5, -1);
  rayDirection.xy -= float2(SCREEN_WIDTH, SCREEN_HEIGHT) / 2;
  rayDirection.y = -rayDirection.y;
  rayDirection.xy *= FOV_90_SPAN_RECIPROCAL;
  rayDirection = normalize(rayDirection);
  
  float3 worldOrigin = float3(0);
  ray ray { worldOrigin, rayDirection };
  
  // Background to show the ray direction.
  half3 background = half3(saturate(abs(rayDirection) / 1.0));
  half3 color = background;
  
  Atom atom = atoms[0];
  auto intersect = RayTracing::atomIntersectionFunction(ray, atom);
  
  if (intersect.accept) {
    // Base color of the sphere.
    half3 diffuseColor = atom.getColor(atomData);
    float shininess = 16.0;
    float lightPower = 40.0;
    
    // From https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model:
    float3 intersectionPoint = ray.origin + ray.direction * intersect.distance;
    float3 normal = normalize(intersectionPoint - atom.origin);
    float3 lightDirection = worldOrigin - intersectionPoint;
    float lightDistance = length(lightDirection);
    lightDirection /= lightDistance;
    
    float lambertian = max(dot(lightDirection, normal), 0.0);
    float specular = 0;
    if (lambertian > 0.0) {
      // 'halfDir' equals 'viewDir' equals 'lightDir' in this case.
//      float3 halfDirection = lightDirection;
      float specAngle = lambertian;
      specular = pow(specAngle, shininess);
    }
    
    // TODO: Make a cutoff so that no atom is completely in the dark.
    // Need to look at PyMOL's rendering code to find the heuristic.
    float scaledLightPower = smoothstep(0, 1, lightPower / lightDistance);
    half3 finalColor = diffuseColor * lambertian * scaledLightPower;
    finalColor += half(specular * scaledLightPower);
    
    color = saturate(finalColor);
  }
  
  outputTexture.write(half4(color, 1), pixelCoords);
}
