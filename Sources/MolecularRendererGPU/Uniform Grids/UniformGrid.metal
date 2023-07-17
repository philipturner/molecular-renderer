//
//  UniformGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/4/23.
//

#ifndef UNIFORM_GRID_H
#define UNIFORM_GRID_H

#include <metal_stdlib>
#include "../Utilities/Constants.metal"
#include "../Utilities/MRAtom.metal"
#include "../Ray Tracing/Ray.metal"
using namespace metal;
using namespace raytracing;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"

// The highest atom density is 176 atoms/nm^3 with diamond. An superdense carbon
// allotrope is theorized with 354 atoms/nm^3 (1), but the greatest superdense
// ones actually built are ~1-3% denser (2). 256 atoms/nm^3 is a close upper
// limit. It provides just enough room for overlapping atoms from nearby voxels
// (216-250 atoms/nm^3).
//
// (1) https://pubs.aip.org/aip/jcp/article-abstract/130/19/194512/296270/Structural-transformations-in-carbon-under-extreme?redirectedFrom=fulltext
// (2) https://www.newscientist.com/article/dn20551-new-super-dense-forms-of-carbon-outshine-diamond/

// 4x4x4 nm^3 voxels, 16384 atoms/voxel, <256 atoms/nm^3
constant uint upper_voxel_atoms_bits = 14;
constant uint upper_voxel_id_bits = 32 - upper_voxel_atoms_bits;
constant uint upper_voxel_id_mask = (1 << upper_voxel_id_bits) - 1;
constant uint upper_voxel_max_atoms = 1 << upper_voxel_atoms_bits;

constant uint equality_mask = 0x80000000;

// TODO: Profile whether 16-bit or 32-bit is faster.
typedef ushort atom_reference;

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
  device REFERENCE *references;
  device MRAtom *atoms;
};

class SparseGrid {
public:
  ushort upper_width;
  ushort low_res_width;
  ushort high_res_width;
  
  device uint *upper_voxel_offsets;
  device uint *lower_offset_offsets;
  device MRAtom *upper_voxel_atoms;
  device atom_reference *final_references;
  device uint *upper_reference_offsets;
  device uint *final_voxel_offsets;
};

// Sources:
// - https://tavianator.com/2022/ray_box_boundary.html
// - https://ieeexplore.ieee.org/document/7349894
template <typename T>
class DenseDDA {
  float3 dt;
  float3 t;
  ushort3 position;
  
  // Progress of the adjusted ray w.r.t. the original ray. This ensures closest
  // hits are recognized in the correct order.
  float tmin; // in the original coordinate space
  float voxel_tmax; // in the relative coordinate space
  
public:
  ushort grid_width;
  uint address;
  bool continue_loop;
  
  DenseDDA(Ray<T> ray, ushort grid_width) {
    half h_grid_width(grid_width);
    this->grid_width = grid_width;
    
    float tmin = 0;
    float tmax = INFINITY;
    dt = precise::divide(1, float3(ray.direction));
    
    // The grid's coordinate space is in half-nanometers.
    // NOTE: This scales `t` by a factor of 0.444/2.25.
    ray.origin *= voxel_width_denom / voxel_width_numer;
    
    // Dense grids start at an offset from the origin.
    // NOTE: This does not change `t`.
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
    // NOTE: This translates `t` by an offset of `tmin`.
    continue_loop = (tmin < tmax);
    ray.origin += tmin * float3(ray.direction);
    ray.origin = clamp(ray.origin, float(0), h_grid_width);
    this->tmin = tmin * voxel_width_numer / voxel_width_denom;
    
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
  
  float get_max_accepted_t() {
    return tmin + voxel_tmax * voxel_width_numer / voxel_width_denom;
  }
  
  void increment_position() {
    ushort2 cond_mask;
    cond_mask[0] = (t.x < t.y) ? 1 : 0;
    cond_mask[1] = (t.x < t.z) ? 1 : 0;
    uint desired = as_type<uint>(ushort2(1, 1));
    
    if (as_type<uint>(cond_mask) == desired) {
      voxel_tmax = t.x; // actually t + dt
      address += VoxelAddress::increment_x(grid_width, dt.x < 0);
      t.x += abs(dt.x); // actually t + dt + dt
      
      position.x += 1;
      continue_loop = (position.x < grid_width);
    } else if (t.y < t.z) {
      voxel_tmax = t.y;
      address += VoxelAddress::increment_y(grid_width, dt.y < 0);
      t.y += abs(dt.y);
      
      position.y += 1;
      continue_loop = (position.y < grid_width);
    } else {
      voxel_tmax = t.z;
      address += VoxelAddress::increment_z(grid_width, dt.z < 0);
      t.z += abs(dt.z);
      
      position.z += 1;
      continue_loop = (position.z < grid_width);
    }
  }
};

namespace old_sparse_grids_draft {
  
  template <typename T>
  class SparseDDA {
    float3 dt;
    float3 t;
    ushort3 upper_position;
    short3 lower_position;
    
    SparseGrid grid;
    float base_tmin;
    float voxel_tmax;
    bool is_high_res;
    
    device MRAtom *atoms;
    device atom_reference *references;
    uint final_offset_offset;
    
  public:
    ushort upper_width;
    ushort lower_width;
    uint upper_address;
    uint lower_address;
    bool continue_upper_loop;
    bool continue_lower_loop;
    bool upper_voxel_empty;
    
    uint upper_id;
    uint cursor;
    uint loop_end;
    
    // Ray must already be transformed into upper voxel space.
    SparseDDA(Ray<T> ray, SparseGrid grid, bool is_high_res) {
      this->grid = grid;
      this->upper_width = grid.upper_width;
      if (is_high_res) {
        this->lower_width = grid.high_res_width;
      } else {
        this->lower_width = grid.low_res_width;
      }
      this->is_high_res = is_high_res;
      
      uint total_width = upper_width * lower_width;
      float f_total_width = float(total_width);
      half h_lower_width = float(lower_width);
      dt = precise::divide(1, float3(ray.direction));
      ray.origin *= h_lower_width;
      
      float tmin = 0;
      float tmax = INFINITY;
#pragma clang loop unroll(full)
      for (int i = 0; i < 3; ++i) {
        float t1 = (0 - ray.origin[i]) * dt[i];
        float t2 = (f_total_width - ray.origin[i]) * dt[i];
        tmin = max(tmin, min(min(t1, t2), tmax));
        tmax = min(tmax, max(max(t1, t2), tmin));
      }
      
      continue_upper_loop = (tmin < tmax);
      continue_lower_loop = false;
      ray.origin += tmin * float3(ray.direction);
      ray.origin = clamp(ray.origin, float(0), f_total_width);
      this->base_tmin = tmin;
      
#pragma clang loop unroll(full)
      for (int i = 0; i < 3; ++i) {
        float direction = ray.direction[i];
        float origin = ray.origin[i];
        
        if (ray.direction[i] < 0) {
          origin = f_total_width - origin;
        }
        uint total_position = uint(origin);
        upper_position[i] = total_position / lower_width;
        lower_position[i] = total_position - lower_width * upper_position[i];
        
        t[i] = (floor(origin) - origin) * abs(dt[i]) + abs(dt[i]);
      }
    }
    
    float get_max_accepted_t() {
      return base_tmin + voxel_tmax;
    }
    
    void start_upper_iteration() {
#pragma clang loop unroll(full)
      for (ushort dim = 0; dim < 3; ++dim) {
        if (lower_position[dim] >= lower_width) {
          lower_position[dim] -= lower_width;
          upper_position[dim] += 1;
        }
      }
      if (any(upper_position >= upper_width)) {
        continue_upper_loop = false;
        return;
      } else {
        continue_upper_loop = true;
      }
      
      {
        ushort3 position = upper_position;
        ushort3 neg_position = upper_width - 1 - position;
        ushort3 actual_position = select(position, neg_position, dt < 0);
        upper_address = VoxelAddress::generate(upper_width, actual_position);
      }
      uint upper_offset = grid.upper_voxel_offsets[upper_address];
      uint upper_count = upper_offset >> upper_voxel_id_bits;
      
      ushort3 position = lower_position;
      ushort3 neg_position = lower_width - 1 - position;
      ushort3 actual_position = select(position, neg_position, dt < 0);
      lower_address = VoxelAddress::generate(lower_width, actual_position);
      
      continue_upper_loop = true;
      cursor = 0;
      loop_end = 0;
      
      if (upper_count == 0) {
        upper_voxel_empty = true;
      } else {
        upper_voxel_empty = false;
        
        upper_id = upper_offset & upper_voxel_id_mask;
        if (is_high_res) {
          upper_id += 1;
        }
        atoms = grid.upper_voxel_atoms + 16384 * upper_id;
        final_offset_offset = 8 * grid.lower_offset_offsets[upper_id];
        
        uint reference_offset = grid.upper_reference_offsets[upper_id];
        references = grid.final_references + reference_offset;
      }
    }
    
    METAL_FUNC void start_lower_iteration() {
      uint offset_address = final_offset_offset + lower_address;
      uint raw_offset = grid.final_voxel_offsets[offset_address];
      uint offset = raw_offset & voxel_offset_mask;
      ushort count = raw_offset / dense_grid_reference_capacity;
      this->cursor = offset;
      this->loop_end = offset + count;
    }
    
    METAL_FUNC void increment_position() {
      ushort2 cond_mask;
      cond_mask[0] = (t.x < t.y) ? 1 : 0;
      cond_mask[1] = (t.x < t.z) ? 1 : 0;
      uint desired = as_type<uint>(ushort2(1, 1));
      
      if (as_type<uint>(cond_mask) == desired) {
        voxel_tmax = t.x; // actually t + dt
        lower_address += VoxelAddress::increment_x(lower_width, dt.x < 0);
        t.x += abs(dt.x); // actually t + dt + dt
        
        lower_position.x += 1;
        continue_lower_loop = (lower_position.x < lower_width);
      } else if (t.y < t.z) {
        voxel_tmax = t.y;
        lower_address += VoxelAddress::increment_y(lower_width, dt.y < 0);
        t.y += abs(dt.y);
        
        lower_position.y += 1;
        continue_lower_loop = (lower_position.y < lower_width);
      } else {
        voxel_tmax = t.z;
        lower_address += VoxelAddress::increment_z(lower_width, dt.z < 0);
        t.z += abs(dt.z);
        
        lower_position.z += 1;
        continue_lower_loop = (lower_position.z < lower_width);
      }
    }
  };
  
};

#pragma clang diagnostic pop

#endif

