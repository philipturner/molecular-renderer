//
//  SparseGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
//

#include <metal_stdlib>
#include "../Utilities/FaultCounter.metal"
#include "UniformGrid.metal"
using namespace metal;

struct SparseGridArguments {
  float3 upper_origin; // unsigned integer in world space
  uint lower_max_atoms;
  uint max_upper_voxels;
  uint max_references;
  
  ushort upper_width;
  ushort lower_width;
  ushort final_width;
  
  float upper_scale;
  float lower_scale;
  float final_scale;
};

// In a single pass, generate the entire upper grid. Eagerly allocate a new zone
// of memory when the grid doesn't have one yet.
kernel void sparse_grid_pass1
(
 constant SparseGridArguments &args [[buffer(0)]],
 constant MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 
 device atomic_uint *upper_grid_size [[buffer(3)]], // start at 1024
 device uint *upper_voxel_offsets [[buffer(4)]],
 device atomic_uint *upper_voxel_sizes [[buffer(5)]],
 device MRAtom *upper_voxel_atoms [[buffer(6)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom(atoms + tid);
  atom.origin = (atom.origin - args.upper_origin) * args.upper_scale;
  MRBoundingBox box = atom.getBoundingBox(styles);
  
  short3 s_min = short3(box.min);
  short3 s_max = short3(box.max);
  s_min = clamp(s_min, 0, args.upper_width);
  s_max = clamp(s_max, 0, args.upper_width);
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
    uint address = VoxelAddress::generate(args.upper_width, box_coords);
    uint offset = upper_voxel_offsets[address];
    
    FaultCounter counter(1000);
    auto object = (device atomic_uint*)(upper_voxel_offsets + address);
    while (offset < 1024) {
      FAULT_COUNTER_RETURN(counter)
      
      uint expected = 0;
      uint desired = 1;
      if (atomic_compare_exchange_weak_explicit(object, &expected, desired,
                                                memory_order_relaxed,
                                                memory_order_relaxed)) {
        offset = atomic_fetch_add_explicit(upper_grid_size,
                                           args.lower_max_atoms,
                                           memory_order_relaxed);
        
        FaultCounter counter(10);
        uint expected = 1;
        while (!atomic_compare_exchange_weak_explicit(object, &expected,
                                                      offset,
                                                      memory_order_relaxed,
                                                      memory_order_relaxed)) {
          FAULT_COUNTER_RETURN(counter)
          expected = 1;
        }
      } else {
        offset = expected;
      }
    }
    
    // TODO: Only if the offset is within bounds, increment the sector size.
    
    // TODO: Only if the offset with the sector < lower_max_atoms, write the
    // atom.
    
    while (permutation_id < 8) {
      permutation_id += 1;
      ushort3 masks(1 << 0, 1 << 1, 1 << 2);
      box_coords = select(box_min, box_max, bool3(permutation_id & masks));
      if (all(box_coords <= box_max)) {
        break;
      }
    }
  }
  
  // Acquire a lock to the sector's data.
}

// TODO: In the next shader, take min(sector_size, lower_max_atoms).
// TODO: In this shader, a loop with two iterations. The first does the default
// spatial resolution. The second takes the higher resolution, if it exists and
// you're close to the user.
