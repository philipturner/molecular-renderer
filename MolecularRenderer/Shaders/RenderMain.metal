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
  
//  // Background to show the ray direction.
//  half3 background = half3(saturate(abs(rayDirection) / 1.0));
//  half3 color = background;
  half3 color = { 0.707, 0.707, 0.707 };
  
  auto intersect = RayTracing::traverseAccelerationStructure(
    ray, accelerationStructure);
  
  if (intersect.accept) {
    // Base color of the sphere.
    Atom atom = intersect.atom;
    half3 diffuseColor = atom.getColor(atomData);
    float shininess = 16.0;
    float lightPower = 40.0;
    
    float3 intersectionPoint = ray.origin + ray.direction * intersect.distance;
    
    // Apply checkerboard to tagged atoms.
    if (atom.flags & 0x1) {
      float3 delta = intersectionPoint - atom.origin;
      bool3 axes_pos = delta > 0;
      bool is_magenta = axes_pos.x ^ axes_pos.y ^ axes_pos.z;
      
//      // Rotate pi/4 radians around any axis (column-major).
//      const float CHANGE = M_SQRT1_2_F * 1.500;
//      const float2x2 cc_rotation(float2(CHANGE, CHANGE),
//                                 float2(-CHANGE, CHANGE));
//
//      float3 normalized_delta = normalize(delta);
//
//      float3 vec = abs(normalized_delta);
//      vec.yz = cc_rotation * vec.yz; // X
//      vec.xy = cc_rotation * vec.xy; // Z
//      bool exceeds_xz = any(vec.xy < 0);
//
//      vec = abs(normalized_delta);
//      vec.zx = cc_rotation * vec.zx; // Y
//      vec.yz = cc_rotation * vec.yz; // X
//      bool exceeds_yx = any(vec.yx < 0);
//
//      vec = abs(normalized_delta);
//      vec.xy = cc_rotation * vec.xy; // Z
//      vec.zx = cc_rotation * vec.zx; // Y
//      bool exceeds_zy = any(vec.zy < 0);
//
//      bool exceeds = exceeds_xz | exceeds_yx | exceeds_zy;
//      //      bool exceeds = exceeds_zy;//all(abs(delta) > 0.1);
      
      float3 n_delta = normalize(abs(delta));
      float center_dsq = distance_squared(n_delta, float3(0.57735));
      float x_dsq = distance_squared(n_delta, float3(1, 0, 0));
      float y_dsq = distance_squared(n_delta, float3(0, 1, 0));
      float z_dsq = distance_squared(n_delta, float3(0, 0, 1));
      
      bool3 exceeds_raw = float3(x_dsq, y_dsq, z_dsq) < 1.700 * center_dsq;
      bool exceeds = any(exceeds_raw);
      
      // Potential source of help:
      // https://www.shadertoy.com/view/cllGzr
      
      // TODO: Each circle is defined by a plane: the 1/2 point between each
      // pair of axes, and a constant direction of curvature. Make a formula
      // that tests whether the point is over/under that plane, then fine-tune
      // the slope. Also select the closest axes, so this test only needs
      // to happen once (if that will improve performance or simplify code).
      
      // If it exceeds the bounds for the center tile, flip the color.
      is_magenta = is_magenta ^ exceeds;
      half3 magenta(223.0 / 255, 48.0 / 255, 235.0 / 255);
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
    // Need to look at PyMOL's rendering code to find the heuristic.
    float scaledLightPower = smoothstep(0, 1, lightPower / lightDistance);
    color = diffuseColor * lambertian * scaledLightPower;
    color += half(specular * scaledLightPower);
    color = saturate(color);
  }
  
  outputTexture.write(half4(color, 1), pixelCoords);
}
