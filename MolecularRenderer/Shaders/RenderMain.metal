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
using namespace raytracing;

constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];
constant float FOV_90_SPAN_RECIPROCAL [[function_constant(2)]];

struct Arguments {
  float3 position;
  float3x3 rotation;
};

// Dispatch threadgroups across 16x16 chunks, not rounded to image size.
// This shader will rearrange simds across 8x2 to 8x8 chunks (depending on the
// GPU architecture).
kernel void renderMain
 (
  texture2d<half, access::write> outputTexture [[texture(0)]],
  
  constant Arguments &args [[buffer(0)]],
  constant AtomStatistics *atomData [[buffer(1)]],
  primitive_acceleration_structure accelerationStructure [[buffer(2)]],
  
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
  rayDirection = args.rotation * rayDirection;
  
  float3 worldOrigin = args.position;
  ray ray { worldOrigin, rayDirection };
  auto intersect = RayTracing::traverseAccelerationStructure(
    ray, accelerationStructure);
  
  half3 color = { 0.707, 0.707, 0.707 };
  if (intersect.accept) {
    Atom atom = intersect.atom;
    float shininess = 16.0;
    float lightPower = 40.0;
    
    // Base color of the sphere.
    half3 diffuseColor;
    if (atom.flags & 0x2) {
      // Replace the diffuse color with black.
      diffuseColor = { 0.000, 0.000, 0.000 };
    } else {
      diffuseColor = atom.getColor(atomData);
    }
    
    float3 intersectionPoint = ray.origin + ray.direction * intersect.distance;
    
    // Apply checkerboard to tagged atoms.
    if (atom.flags & 0x1) {
      // Determine whether the axes are positive.
      float3 delta = intersectionPoint - atom.origin;
      bool3 axes_pos = delta > 0;
      bool is_magenta = axes_pos.x ^ axes_pos.y ^ axes_pos.z;
      
      half3 magenta(252.0 / 255, 0.0 / 255, 255.0 / 255);
      diffuseColor = is_magenta ? magenta : diffuseColor;
    }
    
    // From https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model:
    float3 normal = normalize(intersectionPoint - intersect.atom.origin);
    float3 lightDirection = worldOrigin - intersectionPoint;
    float lightDistance = length(lightDirection);
    lightDirection /= lightDistance;
    
    float lambertian = max(dot(lightDirection, normal), 0.0);
    float specular = 0;
    if (lambertian > 0.0) {
      // 'halfDir' equals 'viewDir' equals 'lightDir' in this case.
      float specAngle = lambertian;
      specular = pow(specAngle, shininess);
    }
    
    // TODO: Make a cutoff so that no atom is completely in the dark.
    // TODO: The specular part looks very strange for colors besides gray.
    // Using the PyMOL rendering algorithm should fix this.
    float scaledLightPower = smoothstep(0, 1, lightPower / lightDistance);
    float3 out = float3(diffuseColor) * lambertian * scaledLightPower;
    out += specular * scaledLightPower;
    color = half3(saturate(out));
  }
  
  outputTexture.write(half4(color, 1), pixelCoords);
}
