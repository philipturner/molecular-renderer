//
//  SparseGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
//

#include <metal_stdlib>
#include "../Utilities/Atomic.metal"
#include "../Utilities/FaultCounter.metal"
#include "UniformGrid.metal"
using namespace metal;

// The highest atom density is 176 atoms/nm^3 with diamond. An superdense carbon
// allotrope is theorized with 354 atoms/nm^3 (1), but the greatest superdense
// ones actually built are only ~1-3% dense (2). 256 atoms/nm^3 is a reasonable
// upper limit. It also provides room for atoms that overlap from nearby voxels.
//
// (1) https://pubs.aip.org/aip/jcp/article-abstract/130/19/194512/296270/Structural-transformations-in-carbon-under-extreme?redirectedFrom=fulltext
// (2) https://www.newscientist.com/article/dn20551-new-super-dense-forms-of-carbon-outshine-diamond/

// 4x4x4 nm^3 voxels, 16384 atoms/voxel, <256 atoms/nm^3
constant uint upper_voxel_atoms_bits = 14;
constant uint upper_voxel_id_bits = 32 - upper_voxel_atoms_bits;
constant uint upper_voxel_id_mask = (1 << upper_voxel_id_bits) - 1;

struct SparseGridArguments {
  // Grid position in world space and camera space.
  float3 upper_origin;
  ushort3 camera_upper_voxel;
  uint high_res_distance_sq;
  
  // Bounds of the sparse grid.
  uint max_upper_voxels;
  uint max_references;
  ushort3 upper_dimensions;
  ushort plane_size;
  
  // Lower voxel size before 2x upscaling.
  ushort lower_width;
  ushort high_res_lower_width;
};


kernel void sparse_grid_pass1
(
 constant SparseGridArguments &args [[buffer(0)]],
 constant MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 
 device atomic_uint *total_upper_voxels [[buffer(3)]], // start at 2
 device atomic_uint *upper_voxel_offsets [[buffer(4)]],
 device MRAtom *upper_voxel_atoms [[buffer(5)]],
 device ushort3 *low_res_coords [[buffer(6)]],
 device ushort3 *high_res_coords [[buffer(7)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom(atoms + tid);
  atom.origin = atom.origin / 4 - args.upper_origin;
  MRBoundingBox box = atom.getBoundingBox(styles);
  
  short3 max_coords = short3(args.upper_dimensions - 1);
  short3 s_min = short3(box.min);
  short3 s_max = short3(box.max);
  s_min = clamp(s_min, 0, max_coords);
  s_max = clamp(s_max, 0, max_coords);
  ushort3 box_min = ushort3(s_min);
  ushort3 box_max = ushort3(s_max);
  
  ushort3 permutation_mask;
#pragma clang loop unroll(full)
  for (ushort i = 0; i < 3; ++i) {
    permutation_mask[i] = (box_max[i] > box_min[i]);
  }
  
  ushort permutation_id = 0;
  ushort3 box_coords = box_min;
  while (permutation_id < 8) {
    uint address = box_coords.x + uint(args.upper_dimensions[0] * box_coords.y);
    address += args.plane_size * box_coords.z;
    uint upper_voxel_id = atomic_load(upper_voxel_offsets + address);
    
    short3 camera_delta = short3(args.camera_upper_voxel - box_coords);
    int camera_distance_sq = camera_delta.x * camera_delta.x;
    camera_distance_sq += camera_delta.y * camera_delta.y;
    camera_distance_sq += camera_delta.z * camera_delta.z;
    
    bool is_close = uint(camera_distance_sq) < args.high_res_distance_sq;
    ushort duplicates = is_close ? 2 : 1;
    
    FaultCounter counter(1000);
    auto object = (device atomic_uint*)(upper_voxel_offsets + address);
    while (upper_voxel_id < 2) {
      FAULT_COUNTER_RETURN(counter)
      
      uint expected = 0;
      uint desired = 1;
      if (atomic_compare_exchange(object, &expected, desired)) {
        upper_voxel_id = atomic_fetch_add(total_upper_voxels, duplicates);
        
        // Increment the 'MTLDispatchThreadgroupsIndirectArguments' for the
        // first command after this one.
        uint low_res_tgid = atomic_fetch_add(total_upper_voxels + 4, 1);
        low_res_coords[low_res_tgid] = box_coords;
        
        // Increment the 'MTLDispatchThreadgroupsIndirectArguments' for the
        // second command after this one.
        if (duplicates == 2) {
          uint high_res_tgid = atomic_fetch_add(total_upper_voxels + 8, 1);
          high_res_coords[high_res_tgid] = box_coords;
        }
        
        FaultCounter counter(10);
        uint expected = 1;
        while (!atomic_compare_exchange(object, &expected, address)) {
          FAULT_COUNTER_RETURN(counter)
          expected = 1;
        }
      } else {
        upper_voxel_id = expected;
      }
    }
    
    upper_voxel_id &= upper_voxel_id_mask;
    
    if (upper_voxel_id < args.max_upper_voxels) {
      uint atom_id = atomic_fetch_add(object, 1 << upper_voxel_id_bits);
      atom_id >>= upper_voxel_id_bits;
      atom_id += uint(1 << upper_voxel_id_bits) * upper_voxel_id;
      
      for (ushort i = 0; i < duplicates; ++i) {
        float scale = (i == 0) ? args.lower_width : args.high_res_lower_width;
        MRAtom scaled = atom;
        scaled.origin *= scale;
        scaled.store(upper_voxel_atoms + atom_id);
        atom_id += uint(1 << upper_voxel_atoms_bits);
      }
    }
    
    while (permutation_id < 8) {
      permutation_id += 1;
      ushort3 masks(1 << 0, 1 << 1, 1 << 2);
      box_coords = select(box_min, box_max, bool3(permutation_id & masks));
      if (all(box_coords <= box_max)) {
        break;
      }
    }
  }
}

constant bool is_high_res [[function_constant(10001)]];

kernel void sparse_grid_pass2
(
 constant SparseGridArguments &args [[buffer(0)]],
 constant MRAtomStyle *styles [[buffer(1)]],
 
 device atomic_uint *upper_voxel_offsets [[buffer(4)]],
 device MRAtom *upper_voxel_atoms [[buffer(5)]],
 device ushort3 *low_res_coords [[buffer(6)]],
 device ushort3 *high_res_coords [[buffer(7)]],
 
 threadgroup uint *threadgroup_block [[threadgroup(0)]],
 uint tgid [[threadgroup_position_in_grid]],
 ushort tg_size [[threads_per_threadgroup]],
 ushort sidx [[simdgroup_index_in_threadgroup]],
 ushort lid [[thread_position_in_threadgroup]])
{
  ushort3 voxel_coords;
  if (is_high_res) {
    voxel_coords = high_res_coords[tgid];
  } else {
    voxel_coords = low_res_coords[tgid];
  }
  ushort row_size = args.upper_dimensions[0];
  uint address = voxel_coords.x + uint(row_size * voxel_coords.y);
  address += args.plane_size * voxel_coords.z;
  
  
}
 
 

