//
//  UniformGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/4/23.
//

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

class DifferentialAnalyzer {
  DenseGrid grid;
  float3 xyz;
  float3 xyz_t;
  float grid_width;
  float min_dt;
  
public:
  // Need to adjust the ray's origin, so it starts inside the box. This probably
  // requires a ray-box intersection test.
  DifferentialAnalyzer(ray ray, DenseGrid grid) {
    this->grid = grid;
    this->xyz = grid.apply_offset(ray.origin);
    this->xyz_t = float3(0);
    
    // When implementing sparse grids, the width and multiplier will be function
    // constants.
    this->grid_width = grid.get_width();
    this->min_dt = precise::divide(1, max3(ray.direction.x,
                                           ray.direction.y,
                                           ray.direction.z));
  }
};

#pragma clang diagnostic pop
