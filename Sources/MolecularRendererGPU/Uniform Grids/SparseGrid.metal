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

// TODO: Profile whether 16-bit or 32-bit is faster.
typedef ushort atom_reference;

struct SparseGridArguments {
  // Grid position in world space and camera space.
  float3 upper_origin;
  ushort3 camera_upper_voxel;
  uint high_res_distance_sq;
  
  // Bounds of the sparse grid.
  uint max_upper_voxels;
  uint max_references;
  ushort3 upper_dimensions;
  ushort upper_plane_size;
  
private:
  ushort4 low_res_stats;
  ushort4 high_res_stats;
  
public:
  // Lower voxel size before 2x upscaling.
  ushort get_lower_width(bool is_high_res) const constant {
    if (is_high_res) {
      return high_res_stats[0];
    } else {
      return low_res_stats[0];
    }
  }
  
  half get_lower_scale(bool is_high_res) const constant {
    if (is_high_res) {
      return as_type<half>(high_res_stats[1]);
    } else {
      return as_type<half>(low_res_stats[1]);
    }
  }
  
  ushort get_num_voxel_slots(bool is_high_res) const constant {
    if (is_high_res) {
      return high_res_stats[2];
    } else {
      return low_res_stats[2];
    }
  }
};

#define SPARSE_BOX_GENERATE \
short3 s_min = short3(box.min); \
short3 s_max = short3(box.max); \
s_min = clamp(s_min, 0, max_coords); \
s_max = clamp(s_max, 0, max_coords); \
ushort3 box_min = ushort3(s_min); \
ushort3 box_max = ushort3(s_max); \

kernel void sparse_grid_pass1
(
 constant SparseGridArguments &args [[buffer(0)]],
 device MRAtomStyle *styles [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 
 device atomic_uint *total_upper_voxels [[buffer(3)]], // start at 2
 device atomic_uint *upper_voxel_offsets [[buffer(4)]],
 device MRAtom *upper_voxel_atoms [[buffer(5)]],
 device ushort4 *upper_voxel_coords [[buffer(6)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom(atoms + tid);
  atom.origin = atom.origin / 4 - args.upper_origin;
  MRBoundingBox box = atom.getBoundingBox(styles);
  
  short3 max_coords = short3(args.upper_dimensions - 1);
  SPARSE_BOX_GENERATE
  
  ushort3 permutation_mask;
#pragma clang loop unroll(full)
  for (ushort i = 0; i < 3; ++i) {
    permutation_mask[i] = (box_max[i] > box_min[i]);
  }
  
  ushort permutation_id = 0;
  ushort3 box_coords = box_min;
  while (permutation_id < 8) {
    uint address = box_coords.x + uint(args.upper_dimensions[0] * box_coords.y);
    address += args.upper_plane_size * box_coords.z;
#define object (upper_voxel_offsets + address)
    uint upper_voxel_id = atomic_load(object);
    
    short3 camera_delta = short3(args.camera_upper_voxel - box_coords);
    int camera_distance_sq = camera_delta.x * camera_delta.x;
    camera_distance_sq += camera_delta.y * camera_delta.y;
    camera_distance_sq += camera_delta.z * camera_delta.z;
    
    // TODO: Cull voxels outside the view frustum.
    bool is_close = uint(camera_distance_sq) < args.high_res_distance_sq;
    ushort duplicates = is_close ? 2 : 1;
    
    FaultCounter counter(1000);
    while (upper_voxel_id < 2) {
      FAULT_COUNTER_RETURN(counter)
      
      uint expected = 0;
      uint desired = 1;
      if (atomic_compare_exchange(object, &expected, desired)) {
        upper_voxel_id = atomic_fetch_add(total_upper_voxels, duplicates);
        upper_voxel_coords[upper_voxel_id] = ushort4(box_coords, 0);
        if (duplicates == 2) {
          upper_voxel_coords[upper_voxel_id + 1] = ushort4(box_coords, 1);
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
      atom_id += upper_voxel_max_atoms * upper_voxel_id;
      
#pragma clang loop unroll(full)
      for (ushort i = 0; i < 2; ++i) {
        if ((i == 0) || (i == 1 && duplicates == 2)) {
          half scale = args.get_lower_scale(i == 1);
          float3 origin = atom.origin * scale;
          
          // Store the radius for now; it will become the square radius later.
          half worldSpaceRadius = atom.getRadius(styles);
          half radius = float(worldSpaceRadius) * scale;
          MRAtom scaled(origin, /*radiusSquared=*/radius, atom.tailStorage);
          
          if (i == 1) {
            atom_id += upper_voxel_max_atoms;
          }
          scaled.store(upper_voxel_atoms + atom_id);
        }
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

#define SPARSE_BOX_GENERATE_2 \
MRAtom atom(upper_voxel_atoms + atom_id); \
half radius = atom.radiusSquared; \
MRBoundingBox box { atom.origin - radius, atom.origin + radius }; \
\
SPARSE_BOX_GENERATE \

#define SPARSE_BOX_LOOP(COORD) \
for (ushort COORD = box_min.COORD; COORD <= box_max.COORD; ++COORD) \

#define SPARSE_BOX_LOOP_START(WIDTH) \
ushort _address_z = VoxelAddress::generate(WIDTH, box_min); \
SPARSE_BOX_LOOP(z) { \
ushort _address_y = _address_z; \
SPARSE_BOX_LOOP(y) { \
ushort _address_x = 1 + (ushort(_address_y / 15) << 4); \
SPARSE_BOX_LOOP(x) { \
ushort slot_address = _address_x \

#define SPARSE_BOX_LOOP_END(WIDTH) \
_address_x += 1; \
if (_address_x % 16 == 0) { \
_address_x += 1; \
}\
} \
_address_y += VoxelAddress::increment_y(WIDTH); \
} \
_address_z += VoxelAddress::increment_z(WIDTH); \
} \

kernel void sparse_grid_pass2
(
 constant SparseGridArguments &args [[buffer(0)]],
 device MRAtomStyle *styles [[buffer(1)]],
 
 device uint *upper_voxel_offsets [[buffer(4)]],
 device MRAtom *upper_voxel_atoms [[buffer(5)]],
 device ushort4 *upper_voxel_coords [[buffer(6)]],
 
 device atomic_uint *total_references [[buffer(7)]],
 device atom_reference *temp_references [[buffer(8)]],
 device atom_reference *final_references [[buffer(9)]],
 
 uint tgid [[threadgroup_position_in_grid]],
 ushort sidx [[simdgroup_index_in_threadgroup]],
 ushort lid [[thread_position_in_threadgroup]])
{
  // Reserve the first bank for counters accessed very often.
  // First zone: ceil_divide(roundup(width * width * width + 1, 32), 15) * 16
  // Second zone: 17 counters
  // Third zone: 47 slots of padding
  constexpr ushort tg_size = 384;
  constexpr ushort simds_per_group = tg_size / 32;
  threadgroup uint _scratch[32768 / 4];
  threadgroup uint* scratch = _scratch + tgid % 47;
  
  ushort virtual_lid = 1 + (lid / 15) * 16;
  ushort virtual_group_size = (tg_size / 15) * 16;
  
  ushort4 raw_coords = upper_voxel_coords[tgid];
  ushort3 voxel_coords = raw_coords.xyz;
  bool is_high_res = raw_coords.w;
  
  constexpr ushort NUM_MISC_SLOTS = 3;
  ushort lower_width = args.get_lower_width(is_high_res);
  ushort num_voxel_slots = args.get_num_voxel_slots(is_high_res);
  {
    ushort num_slots = num_voxel_slots + NUM_MISC_SLOTS;
    for (ushort i = 0; i < num_slots; i += tg_size) {
      scratch[i] = 0;
    }
  }
  
  ushort row_size = args.upper_dimensions[0];
  uint address = voxel_coords.x + uint(row_size * voxel_coords.y);
  address += args.upper_plane_size * voxel_coords.z;
  
  uint raw_offset = upper_voxel_offsets[address];
  ushort atom_count = raw_offset >> upper_voxel_id_bits;
  uint voxel_offset = raw_offset & upper_voxel_id_mask;
  if (is_high_res) {
    voxel_offset += 1;
  }
  voxel_offset *= upper_voxel_max_atoms;
  
  // Count the number of downscaled references.
  threadgroup_barrier(mem_flags::mem_threadgroup);
  {
    uint atom_id = voxel_offset + lid;
    uint atom_end = voxel_offset + atom_count;
    ushort max_coords = lower_width - 1;
    
    for (; atom_id < atom_end; atom_id += tg_size) {
      // TODO: Reorder loop iterations to reduce divergence.
      SPARSE_BOX_GENERATE_2
      SPARSE_BOX_LOOP_START(lower_width);
      atomic_fetch_add_(scratch + slot_address, 1);
      SPARSE_BOX_LOOP_END(lower_width);
    }
  }
  
  constexpr uint offset_bits = 4 + upper_voxel_atoms_bits;
  constexpr uint offset_mask = (1 << offset_bits) - 1;
  auto counters = scratch + num_voxel_slots;
  threadgroup_barrier(mem_flags::mem_threadgroup);
  {
    ushort lane_id = lid % 32;
    ushort slot_id = virtual_lid;
    for (; slot_id < num_voxel_slots; slot_id += virtual_group_size) {
      uint count = scratch[slot_id];
      uint reduced = simd_prefix_exclusive_sum(count);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wuninitialized"
      uint threadgroup_offset;
      if (lane_id == 31) {
        uint sum = reduced + count;
        threadgroup_offset = atomic_fetch_add_(counters + 0, sum);
      }
      reduced += simd_broadcast(threadgroup_offset, 31);
#pragma clang diagnostic pop
      scratch[slot_id] = (count << offset_bits) | (reduced & offset_mask);
    }
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup);
  if (sidx == 0) {
    uint group_offset = *counters;
    uint device_offset = atomic_fetch_add(total_references + 0, group_offset);
    ushort lane_id = lid % 32;
    if (lane_id <= simds_per_group) {
      counters[lane_id] = (lane_id == 0) ? 0 : device_offset;
    }
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup);
  uint device_offset = counters[1 + sidx];
  {
    uint atom_id = voxel_offset + lid;
    uint atom_end = voxel_offset + atom_count;
    ushort max_coords = lower_width - 1;
    
    for (; atom_id < atom_end; atom_id += tg_size) {
      // TODO: Reorder loop iterations to reduce divergence.
      SPARSE_BOX_GENERATE_2
      SPARSE_BOX_LOOP_START(lower_width);
      uint offset = atomic_fetch_add_(scratch + slot_address, 1);
      offset = offset & offset_mask;
      offset += device_offset;
      
      ushort value = atom_id & (upper_voxel_max_atoms - 1);
      temp_references[offset] = value;
      SPARSE_BOX_LOOP_END(lower_width);
    }
  }
  
  threadgroup_barrier(mem_flags::mem_threadgroup);
  {
    ushort slot_id = virtual_lid;
    for (; slot_id < num_voxel_slots; slot_id += virtual_group_size) {
      uint raw_offset = scratch[slot_id];
      uint count = raw_offset >> offset_bits;
      uint offset = raw_offset & offset_mask;
      scratch[slot_id] = offset - count;
    }
  }
  
  // TODO: -
  //
  // Perform a cheaper version of the upscaling pass, just to allocate memory
  // for the respective voxels. Don't write any references or redistribute any
  // work yet.
  //
  // Find the bounding box, then mark which cells it overlaps. Clamp the atom's
  // bounding box to the 2x2x2 box covered by the current cell.
  
  // Estimate the number of upscaled references.
  threadgroup_barrier(mem_flags::mem_threadgroup | mem_flags::mem_device);
  {
    ushort lane_id = lid % 32;
    ushort slot_id = virtual_lid;
    for (; slot_id < num_voxel_slots; slot_id += virtual_group_size) {
      uint offset = offset_mask & scratch[slot_id];
      uint next_slot = slot_id + 1;
      if (next_slot % 16 == 0) {
        next_slot += 1;
      }
      uint next_offset = offset_mask & scratch[next_slot];
      
      uint is_occupied = (next_offset > offset);
      uint reduced = simd_prefix_exclusive_sum(is_occupied);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wuninitialized"
      uint threadgroup_offset;
      if (lane_id == 31) {
        uint sum = reduced + is_occupied;
        threadgroup_offset = atomic_fetch_add_(counters + 0, sum);
      }
      reduced += simd_broadcast(threadgroup_offset, 31);
#pragma clang diagnostic pop
      if (next_offset > offset) {
        reduced = 1 + ((reduced / 15) << 4);
        uint operand = slot_id << offset_bits;
        atomic_fetch_or_(scratch + reduced, operand);
        
        ushort sub_voxel_counts[8];
  #pragma clang loop unroll(full)
        for (ushort i = 0; i < 8; ++i) {
          sub_voxel_counts[i] = 0;
        }
        
        offset += device_offset;
        next_offset += device_offset;
        ushort max_coords = lower_width - 1;
        
        for (; offset < next_offset; ++offset) {
          uint atom_id = voxel_offset + temp_references[offset];
          SPARSE_BOX_GENERATE_2
        }
      }
    }
  }
  
  // Transform the radii into square radii.
  threadgroup_barrier(mem_flags::mem_device);
  {
    uint atom_id = voxel_offset + lid;
    uint atom_end = voxel_offset + atom_count;
    half scale = args.get_lower_scale(is_high_res);
    
    for (; atom_id < atom_end; atom_id += tg_size) {
      auto atom_base = (device float4*)(upper_voxel_atoms + atom_id);
      ushort2 tail = as_type<ushort2>(atom_base->w);
      uint element = tail[1] & 255;
      
      auto style_base = (device half4*)(styles + element);
      half actualRadius = style_base->w;
      float radius = float(actualRadius) * float(scale);
      half radiusSquared = float(radius * radius);
      tail[0] = as_type<ushort>(radiusSquared);
      atom_base->w = as_type<float>(tail);
    }
  }
  
  // Generate the references, using an expensive atom-cell intersection test.
  threadgroup_barrier(mem_flags::mem_device);
  {
    // https://stackoverflow.com/questions/4578967/c
    // TODO: Store cube in sphere-space, pre-compute S - C.
  }
}
