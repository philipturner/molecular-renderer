//
//  UniformGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/4/23.
//

#ifndef UNIFORM_GRID_H
#define UNIFORM_GRID_H

#include <metal_stdlib>
#include "MRAtom.metal"
using namespace metal;
using namespace raytracing;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"

// Voxel width in nm.
constant float voxel_width = 0.5;

// Max 1 million atoms/dense grid, including duplicated references.
// Max 65536 atoms/dense grid, excluding duplicated references.
constant uint voxel_offset_mask = 0x000FFFFF;

// Max 4096 atoms/voxel. This is stored in opposite-endian order to the offset.
constant uint voxel_count_mask = 0xFFF00000;

// Behavior is undefined when the position goes out-of-bounds.
class VoxelAddress {
public:
  static uint generate(ushort grid_width, ushort3 coords) {
    uint grid_width_sq = grid_width * grid_width;
    return coords.z * grid_width_sq + coords.y * grid_width + coords.x;
  }
  
  static int increment_x(ushort grid_width, bool negative = false) {
    return select(1, -1, negative);
  }
  
  static int increment_y(ushort grid_width, bool negative = false) {
    short w = short(grid_width);
    return select(w, short(-w), negative);
  }
  
  static int increment_z(ushort grid_width, bool negative = false) {
    int w_sq = grid_width * grid_width;
    return select(w_sq, -w_sq, negative);
  }
};

class DenseGrid {
public:
  ushort width;
  device uint *data;
  device ushort *references;
  device MRAtom *atoms;
  
  DenseGrid(ushort width,
            device uint *data,
            device ushort *references,
            device MRAtom *atoms)
  {
    this->width = width;
    this->data = data;
    this->references = references;
    this->atoms = atoms;
  }
};

// Sources:
// - https://tavianator.com/2022/ray_box_boundary.html
// - https://ieeexplore.ieee.org/document/7349894
class DifferentialAnalyzer {
  float3 dt;
  float3 t;
  ushort3 position;
  
public:
  ushort grid_width;
  uint address;
  bool continue_loop;
  
  DifferentialAnalyzer(ray ray, DenseGrid grid) {
    half h_grid_width(grid.width);
    grid_width = grid.width;
    
    float tmin = 0;
    float tmax = INFINITY;
    dt = precise::divide(1, ray.direction);
    
    // The grid's coordinate space is in half-nanometers.
    ray.origin /= voxel_width;
    
    // Dense grids start at an offset from the origin.
    ray.origin += h_grid_width * 0.5;
    
    // Perform a ray-box intersection test.
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      float t1 = (0 - ray.origin[i]) * dt[i];
      float t2 = (h_grid_width - ray.origin[i]) * dt[i];
      tmin = max(tmin, min(min(t1, t2), tmax));
      tmax = min(tmax, max(max(t1, t2), tmin));
    }
    
    // Adjust the origin so it starts in the grid.
    continue_loop = (tmin < tmax);
    ray.origin += tmin * ray.direction;
    ray.origin = clamp(ray.origin, float(0), h_grid_width);
    
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      float direction = ray.direction[i];
      float origin = ray.origin[i];
      
      if (ray.direction[i] < 0) {
        origin = h_grid_width - origin;
      }
      position[i] = ushort(origin);
      
      // `t` is actually the future `t`. When incrementing each dimension's `t`,
      // which one will produce the smallest `t`? This dimension gets the
      // increment because we want to intersect the closest voxel, which hasn't
      // been tested yet.
      t[i] = (floor(origin) - origin) * abs(dt[i]) + abs(dt[i]);
    }
    
    ushort3 neg_position = grid_width - 1 - position;
    ushort3 actual_position = select(position, neg_position, dt < 0);
    address = VoxelAddress::generate(grid_width, actual_position);
  }
  
  void increment_position() {
    ushort2 cond_mask;
    cond_mask[0] = (t.x < t.y) ? 1 : 0;
    cond_mask[1] = (t.x < t.z) ? 1 : 0;
    uint desired = as_type<uint>(ushort2(1, 1));
    
    if (as_type<uint>(cond_mask) == desired) {
      address += VoxelAddress::increment_x(grid_width, dt.x < 0);
      t.x += abs(dt.x);
      
      position.x += 1;
      continue_loop = (position.x < grid_width);
    } else if (t.y < t.z) {
      address += VoxelAddress::increment_y(grid_width, dt.y < 0);
      t.y += abs(dt.y);
      
      position.y += 1;
      continue_loop = (position.y < grid_width);
    } else {
      address += VoxelAddress::increment_z(grid_width, dt.z < 0);
      t.z += abs(dt.z);
      
      position.z += 1;
      continue_loop = (position.z < grid_width);
    }
  }
};

#pragma clang diagnostic pop

#endif

