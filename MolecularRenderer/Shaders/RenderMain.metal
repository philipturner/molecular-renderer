//
//  RenderMain.metal
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

#include <metal_stdlib>
#include "AtomStatistics.metal"
#include "RayTracing.metal"
#include "RayGeneration.metal"
using namespace metal;
using namespace raytracing;

// This does not need to become dynamic. Changing the resolution will mess up
// MetalFX upscaling.
constant uint SCREEN_WIDTH [[function_constant(0)]];
constant uint SCREEN_HEIGHT [[function_constant(1)]];
constant bool USE_METALFX [[function_constant(2)]];

#define USE_RTAO 1
#define DEBUG_MOTION_VECTORS 0
#define DEBUG_MOTION_VECTORS_USING_ORIENTATION 0
#define DEBUG_DEPTH 0

struct Arguments {
  // This frame's position and orientation.
  float3 position;
  float3x3 rotation;
  
  // How many pixels are covered in either direction @ FOV=90?
  float fov90Span;
  float fov90SpanReciprocal;
  
  // The jitter to apply to the pixel.
  float2 jitter;
  
  // Frame ID for generating random numbers.
  uint frameNumber;
};

// Dispatch threadgroups across 16x16 chunks, not rounded to image size.
// This shader will rearrange simds across 8x4 chunks, then subdivide further
// into 2x2 (quads) and 4x4 (half-simds). The thread arrangement should
// accelerate intersections with OpenMM tiles in supermassive acceleration
// structures.
kernel void renderMain
 (
  constant Arguments *args [[buffer(0)]],
  constant AtomStatistics *atomData [[buffer(1)]],
  primitive_acceleration_structure accelerationStructure [[buffer(2)]],
  
  texture2d<half, access::write> colorTexture [[texture(0)]],
  texture2d<float, access::write> depthTexture [[texture(1), function_constant(USE_METALFX)]],
  texture2d<half, access::write> motionTexture [[texture(2), function_constant(USE_METALFX)]],
  
  ushort2 tid [[thread_position_in_grid]],
  ushort2 tgid [[threadgroup_position_in_grid]],
  ushort2 local_id [[thread_position_in_threadgroup]])
{
  // Rearrange 16x16 into a hierarchy of levels to maximize memory coalescing
  // during ray tracing:
  // - 16x16 (highest level)
  // - 16x8 (half-threadgroup)
  // - 8x8 (quarter-threadgroup)
  // - 8x4 (simd)
  // - 4x4 (half-simd)
  // - 4x2 (quarter-simd)
  // - 2x2 (quad)
  ushort local_linear_id = local_id.y * 16 + local_id.x;
  ushort new_y = (local_linear_id >= 128) ? 8 : 0;
  ushort new_x = (local_linear_id % 128 >= 64) ? 8 : 0;
  new_y += (local_linear_id % 64 >= 32) ? 4 : 0;
  new_x += (local_linear_id % 32 >= 16) ? 4 : 0;
  new_y += (local_linear_id % 16 >= 8) ? 2 : 0;
  new_x += (local_linear_id % 8 >= 4) ? 2 : 0;
  new_y += (local_linear_id % 4 >= 2) ? 1 : 0;
  new_x += local_linear_id % 2 >= 1;
  
  ushort2 pixelCoords = tgid * 16 + ushort2(new_x, new_y);
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
  if (USE_METALFX) {
    rayDirection.xy += args->jitter;
  }
  rayDirection.xy -= float2(SCREEN_WIDTH, SCREEN_HEIGHT) / 2;
  rayDirection.y = -rayDirection.y;
  rayDirection.xy *= args->fov90SpanReciprocal;
  rayDirection = normalize(rayDirection);
  float rayDirectionZ = rayDirection.z;
  rayDirection = args->rotation * rayDirection;
  
  float3 worldOrigin = args->position;
  ray ray { worldOrigin, rayDirection };
  auto intersect = RayTracing::traverseAccelerationStructure(
    ray, accelerationStructure);
  
  half3 color = { 0.707, 0.707, 0.707 };
  half2 motionVector = 0;
  float depth = -FLT_MAX;
  
  // Shade in the color.
  if (intersect.accept) {
    Atom atom = intersect.atom;
    constexpr float shininess = 16.0;
    constexpr float lightPower = 40.0;
    
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
    
    // TODO: The specular part looks very strange for colors besides gray.
    // Using the PyMOL rendering algorithm should fix this.
    float scaledLightPower = smoothstep(0, 1, lightPower / lightDistance);
    float3 out = float3(diffuseColor) * lambertian * scaledLightPower;
    out += specular * scaledLightPower;
    if (USE_RTAO) {
      // TODO: Do you apply occlusion before or after the specular part?
      float occlusion = RayGeneration::queryOcclusion
       (
        intersectionPoint, atom, pixelCoords, args->frameNumber,
        accelerationStructure);
      out *= occlusion;
    }
    color = half3(saturate(out));
    
    if (DEBUG_MOTION_VECTORS || USE_METALFX) {
      float3 direction = normalize(intersectionPoint - args[1].position);
      direction = transpose(args[1].rotation) * direction;
      direction *= args[1].fov90Span / direction.z;
      
      if (DEBUG_MOTION_VECTORS_USING_ORIENTATION && !USE_METALFX) {
        direction /= 40;
        color.r = direction.x;
        color.g = direction.y;
        color.b = direction.z;
      } else {
        // Write the depth as the intersection point's Z coordinate.
        depth = rayDirectionZ * intersect.distance;
        
        // I have no idea why, but the X coordinate is flipped here.
        float2 prevCoords = direction.xy;
        prevCoords.x = -prevCoords.x;
        
        // Recompute the current pixel coordinates (do not waste registers).
        float2 currCoords = float2(pixelCoords) + 0.5;
        currCoords.xy -= float2(SCREEN_WIDTH, SCREEN_HEIGHT) / 2;
        
        // Generate the motion vector from pixel coordinates.
        motionVector = half2(currCoords - prevCoords);
        
        // I have no idea why, but the Y coordinate is flipped here.
        motionVector.y = -motionVector.y;
      }
    }
  }
  
  if (DEBUG_MOTION_VECTORS && !USE_METALFX) {
    if (!DEBUG_MOTION_VECTORS_USING_ORIENTATION) {
      float magnitude = length(motionVector);
      if (magnitude > 0.25) {
        magnitude = log2(magnitude) + 2;
      } else {
        magnitude = 0;
      }
      half3 colors[1 + 5] = {
        half3(0.000, 0.000, 0.000), // 0
        half3(1.000, 0.000, 0.000), // 2^-1
        half3(0.707, 0.707, 0.000), // 2^0
        half3(0.000, 1.000, 0.000), // 2^1
        half3(0.000, 0.707, 0.707), // 2^2
        half3(0.000, 0.000, 1.000), // 2^3
      };
      
      if (magnitude < 5) {
        int lower_index = int(magnitude);
        int upper_index = lower_index + 1;
        float t = magnitude - float(lower_index);
        color = mix(colors[lower_index], colors[upper_index], t);
      } else {
        color = colors[5];
      }
    }
  }
  
  // Write the output color.
  if (DEBUG_DEPTH && !USE_METALFX) {
    color = 1 / float(1 - depth);
  }
  colorTexture.write(half4(color, 1), pixelCoords);
  
  if (USE_METALFX) {
    // Write the output depth.
    depth = 1 / float(1 - depth); // map (0, -infty) to (1, 0)
    depthTexture.write(float4{ depth }, pixelCoords);
    
    // Write the output motion vectors.
    motionVector = clamp(motionVector, -HALF_MAX, HALF_MAX);
    motionTexture.write(half4{ motionVector.x, motionVector.y }, pixelCoords);
  }
}
