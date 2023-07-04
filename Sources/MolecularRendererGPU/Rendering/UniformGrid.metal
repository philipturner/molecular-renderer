//
//  UniformGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/4/23.
//

#ifndef UNIFORM_GRID_H
#define UNIFORM_GRID_H

#include <metal_stdlib>
using namespace metal;
using namespace raytracing;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"

// Cell width in nm.
constant float cell_width = 0.5;

// Max 1 million atoms/dense grid, including duplicated references.
// Max 65536 atoms/dense grid, excluding duplicated references.
constant uint cell_offset_mask = 0x000FFFFF;

// Max 4096 atoms/cell. This is stored in opposite-endian order to the offset.
constant uint cell_count_mask = 0xFFF00000;

class DenseGrid {
  // TODO: Store this in half-precision and upcast to FP32 before using. Once we
  // implement sparse grids, it should be a function constant.
  float grid_width; // up to 128 (64 nm)
  // total voxels up to 2^21
  
public:
  DenseGrid() {
    
  }
  
  DenseGrid(ushort grid_width) {
    this->grid_width = float(grid_width);
  }
  
  float get_width() const {
    return grid_width;
  }
  
  float3 apply_offset(float3 position) const {
    return position + grid_width * 0.5;
  }
  
  float address(float3 coords) const {
    float output = fma(coords.y, grid_width, coords.x);
    return fma(coords.z, grid_width * grid_width, output);
  }
  
  uint read(device uint* data, float3 coords) const {
    return data[uint(address(coords))];
  }
  
  uint increment(device atomic_uint* data, float3 coords) {
    auto object = data + uint(address(coords));
    return atomic_fetch_add_explicit(object, 1, memory_order_relaxed);
  }
};

// Sources:
// - https://tavianator.com/2022/ray_box_boundary.html
// - https://ieeexplore.ieee.org/document/7349894
class DifferentialAnalyzer {
  float3 dt;
  half3 position;
  half3 step;
  half3 stop;
  float3 t;
  bool continue_loop;
  
public:
  DifferentialAnalyzer(ray ray, DenseGrid grid) {
    half grid_width = grid.get_width();
    float tmin = 0;
    float tmax = INFINITY;
    dt = precise::divide(1, ray.direction);
    
    // Dense grids start at an offset from the origin.
    ray.origin += grid_width * 0.5;
    
    // Perform a ray-box intersection test.
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      float t1 = (0 - ray.origin[i]) * dt[i];
      float t2 = (grid_width - ray.origin[i]) * dt[1];
      tmin = max(tmin, min(min(t1, t2), tmax));
      tmax = min(tmax, max(max(t1, t2), tmin));
    }
    
    // Adjust the origin so it starts in the grid.
    continue_loop = (tmin < tmax);
    ray.origin += tmin * ray.direction;
    
#pragma clang loop unroll(full)
    for (int i = 0; i < 3; ++i) {
      float direction = ray.direction[i];
      float origin = ray.origin[i];
      position[i] = (direction > 0) ? floor(origin) : ceil(origin);
      step[i] = (direction > 0) ? 1 : -1;
      stop[i] = (direction > 0) ? grid_width : -1;
      
      // `t` is actually the future `t`. When incrementing each dimension's `t`,
      // which one will produce the smallest `t`? This dimension gets the
      // increment because we want to intersect the closest voxel, which hasn't
      // been tested yet.
      t[i] = float(position[i] - origin) * dt[i] + abs(dt[i]);
    }
  }
  
  // Call this just before running the intersection test.
  bool get_continue_loop() const {
    return continue_loop;
  }
  
  // This value is undefined when the loop should be stopped.
  half3 get_position() const {
    return position;
  }
  
  // Call this after, not before, running the intersection test.
  void update_position() {
    ushort2 cond_mask;
    cond_mask[0] = (t.x < t.y) ? 1 : 0;
    cond_mask[1] = (t.x < t.z) ? 1 : 0;
    uint desired = as_type<uint>(ushort2(1, 1));
    
    if (as_type<uint>(cond_mask) == desired) {
      position.x += step.x;
      t.x += abs(t.x);
      continue_loop = (position.x != stop.x);
    } else if (t.y < t.z) {
      position.y += step.y;
      t.y += abs(t.y);
      continue_loop = (position.y != stop.y);
    } else {
      position.z += step.z;
      t.z += abs(t.z);
      continue_loop = (position.z != stop.z);
    }
  }
};

#pragma clang diagnostic pop

#endif
