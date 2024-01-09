//
//  Serialization.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/26/23.
//

#include <metal_stdlib>
#include "../Utilities/MRAtom.metal"
using namespace metal;

struct process_atoms_arguments {
  ushort cluster_size;
  float scale_factor;
  float inverse_scale_factor;
};

constant bool encode [[function_constant(300)]];

inline uint encode_position(int position, thread int *cumulative) {
  int delta = position - *cumulative;
  *cumulative = position;
  
  uint quantized = uint(abs(delta)) << 1;
  quantized |= select(uint(0), uint(1), delta < 0);
  return quantized;
}

inline int decode_position(uint delta, thread int *cumulative) {
  ushort sign = delta & 1;
  delta >>= 1;
  
  int output = select(int(delta), -int(delta), sign);
  *cumulative += output;
  return *cumulative;
}

inline ushort encode_tail(ushort tail, thread ushort *cumulative) {
  tail = as_type<ushort>(as_type<uchar2>(tail).yx);
  tail &= 0x7FFF;
  short delta = short(tail) - short(*cumulative);
  *cumulative = tail;
  
  ushort quantized = ushort(abs(delta)) << 1;
  quantized |= select(ushort(0), ushort(1), delta < 0);
  return quantized;
}

inline ushort decode_tail(ushort delta, thread ushort *cumulative) {
  ushort sign = delta & 1;
  delta >>= 1;
  
  short output = select(int(delta), -int(delta), sign);
  *cumulative += output;
  return as_type<ushort>(as_type<uchar2>(*cumulative).yx);
}

kernel void process_atoms
(
 constant process_atoms_arguments &args [[buffer(0)]],
 constant uint2 *frame_ranges [[buffer(1)]],
 
 device MRAtom *atoms [[buffer(2)]],
 device ushort *tail_components [[buffer(3)]],
 device uint *x_components [[buffer(4)]],
 device uint *y_components [[buffer(5)]],
 device uint *z_components [[buffer(6)]],
 
 uint tid [[thread_position_in_grid]])
{
  int xyz_cumulative[3] = { 0, 0, 0 };
  ushort tail_cumulative = 0;
  
  for (uint frame = 0; frame < args.cluster_size; ++frame) {
    uint2 range = frame_ranges[frame];
    uint cursor = range[0] + tid;
    
    if (encode) {
      MRAtom atom;
      if (tid < range[1]) {
        atom = MRAtom(atoms + cursor);
      } else {
        atom = MRAtom(float3(0), ushort(0));
      }
      
      int3 xyz = int3(rint(atom.origin * args.scale_factor));
      x_components[cursor] = encode_position(xyz.x, xyz_cumulative + 0);
      y_components[cursor] = encode_position(xyz.y, xyz_cumulative + 1);
      z_components[cursor] = encode_position(xyz.z, xyz_cumulative + 2);
      tail_components[cursor] = encode_tail(atom.tailStorage, &tail_cumulative);
    } else {
      if (tid >= range[1]) {
        continue;
      }
      
      int x = decode_position(x_components[cursor], xyz_cumulative + 0);
      int y = decode_position(y_components[cursor], xyz_cumulative + 1);
      int z = decode_position(z_components[cursor], xyz_cumulative + 2);
      ushort tail = decode_tail(tail_components[cursor], &tail_cumulative);
      
      float3 xyz = float3(x, y, z) * args.inverse_scale_factor;
      MRAtom atom(xyz, tail);
      atom.store(atoms + cursor);
    }
  }
}
