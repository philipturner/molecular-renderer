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
  ray ray1 = RayGeneration::primaryRay(pixelCoords, args);
  IntersectionResult intersect1;
  ushort error_code = 0;
  if (args->use_uniform_grid && pixelCoords.x >= 320) {
    intersect1 = RayTracing::traverse_dense_grid(ray1, grid, &error_code);
  } else {
    intersect1 = RayTracing::traverse(ray1, accel);
  }
  
  // Calculate specular, diffuse, and ambient occlusion.
  auto colorCtx = ColorContext(args, styles, pixelCoords);
  if (intersect1.accept) {
    float3 hitPoint = ray1.origin + ray1.direction * intersect1.distance;
    float3 normal = normalize(hitPoint - intersect1.atom.origin);
    colorCtx.setDiffuseColor(intersect1.atom, normal);
    
    if (args->sampleCount > 0) {
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
      
      uint pixelSeed = as_type<uint>(pixelCoords);
      uint seed = Sampling::tea(pixelSeed, args->frameSeed);
      
      for (ushort i = 0; i < args->sampleCount; ++i) {
        // TODO: Move the ray generation logic into another file.
        
        // Generate a random number and increment the seed.
        float random1 = Sampling::radinv3(seed);
        float random2 = Sampling::radinv2(seed);
        seed += 1;
       
        float sampleCountRecip = fast::divide(1, float(args->sampleCount));
        float minimum = float(i) * sampleCountRecip;
        float maximum = minimum + sampleCountRecip;
        maximum = (i == args->sampleCount - 1) ? 1 : maximum;
        random1 = mix(minimum, maximum, random1);
        
        // Create a random ray from the cosine distribution.
        RayGeneration::Basis basis { axes, random1, random2 };
        ray ray2 = RayGeneration::secondaryRay(origin, basis);
        ray2.max_distance = args->maxRayHitTime;
        
        // Cast the secondary ray.
        IntersectionResult intersect2;
        if (args->use_uniform_grid && pixelCoords.x >= 320) {
          intersect2 = RayTracing::traverse_dense_grid(ray2, grid, &error_code);
        } else {
          intersect2 = RayTracing::traverse(ray2, accel);
        }
        
        float diffuseAmbient = 1;
        float specularAmbient = 1;
        if (intersect2.accept) {
          // TODO: Move the light adjustment logic into another file.
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
          half3 neighborColor = intersect2.atom.getColor(styles);
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
    
    // Write the depth as the intersection point's Z coordinate.
    float depth = ray1.direction.z * intersect1.distance;
    colorCtx.setDepth(depth);
    colorCtx.generateMotionVector(hitPoint);
  }
  
  colorCtx.write(color_texture, depth_texture, motion_texture, error_code);
}

// MARK: - Temporary Implementation of RayTracing::traverse_dense_grid

IntersectionResult RayTracing::traverse_dense_grid
(
 const ray ray, const DenseGrid const_grid, thread ushort *error_code)
{
  DenseGrid grid = const_grid;
  DifferentialAnalyzer dda(ray, grid);
  float result_distance = MAXFLOAT;
  ushort result_atom = 65535;
  
  // Error codes:
  // 1 - red
  // 2 - orange
  // 3 - green
  // 4 - cyan
  // 5 - blue
  // 6 - magenta
  // 7 - force 'no error'
  
  int fault_counter1 = 0;
  while (dda.continue_loop) {
    // To reduce divergence, fast forward through empty voxels.
    uint voxel_data = 0;
    bool continue_fast_forward = true;
    while (continue_fast_forward) {
      fault_counter1 += 1; if (fault_counter1 > 100) { *error_code = 5; return { MAXFLOAT, false }; }
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
    
    // TODO: Try delaying the acceptance of a result. Maybe the closest object
    // doesn't appear in the closest voxel?
    int fault_counter2 = 0;
    for (ushort i = 0; i < count; ++i) {
      fault_counter2 += 1; if (fault_counter2 > 300) { *error_code = 6; return { MAXFLOAT, false }; }
      ushort reference = grid.references[offset + i];
      MRAtom atom = grid.atoms[reference];
      
      auto intersect = RayTracing::atomIntersectionFunction(ray, atom);
      if (intersect.accept) {
        result_atom = (intersect.distance < result_distance)
        ? reference : result_atom;
        result_distance = min(intersect.distance, result_distance);
      }
    }
    if (result_distance < MAXFLOAT) {
      dda.continue_loop = false;
    }
  }
  
  IntersectionResult result { result_distance, result_distance < MAXFLOAT };
  if (result_distance < MAXFLOAT) {
    result.atom = grid.atoms[result_atom];
  }
  return result;
}
