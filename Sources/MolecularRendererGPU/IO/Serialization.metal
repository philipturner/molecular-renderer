//
//  Serialization.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/23/23.
//

#include <metal_stdlib>
#include "../Utilities/MRAtom.metal"
using namespace metal;

struct serialization_arguments {
  uint batch_stride;
  float scale_factor;
  float inverse_scale_factor;
};

inline uint encode_difference(uint next, uint previous) {
  int difference = int(next) - int(previous);
  uint magnitude = abs(difference);
  return (magnitude << 1) | (difference < 0 ? 1 : 0);
}

inline uint decode_difference(uint previous, uint difference) {
  int magnitude = difference >> 1;
  if (difference & 1) {
    magnitude = -magnitude;
  }
  return uint(int(previous) + magnitude);
}

kernel void serialize
(
 constant serialization_arguments &args [[buffer(0)]],
 device uint4 *cumulativeSum [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 device uint *components [[buffer(3)]],
 
 uint tid [[thread_position_in_grid]])
{
  MRAtom atom(atoms + tid);
  uint4 sum = cumulativeSum[tid];
  
#pragma clang loop unroll(full)
  for (ushort dim = 0; dim < 3; ++dim) {
    float quantized_f = rint(atom.origin[dim] * args.scale_factor);
    uint quantized_i = uint(abs(quantized_f)) << 1;
    quantized_i |= (quantized_f < 0) ? 1 : 0;
    
    atom.origin[dim] = as_type<float>(quantized_i);
    sum[dim] = encode_difference(quantized_i, sum[dim]);
  }
  sum[3] = encode_difference(atom.tailStorage, sum[3]);
  
  atom.store((device MRAtom*)(cumulativeSum + tid));
#pragma clang loop unroll(full)
  for (ushort i = 0; i < 4; ++i) {
    components[tid + i * args.batch_stride] = sum[i];
  }
}

kernel void deserialize
(
 constant serialization_arguments &args [[buffer(0)]],
 device uint4 *cumulativeSum [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 device uint *components [[buffer(3)]],
 
 uint tid [[thread_position_in_grid]])
{
  uint4 sum = cumulativeSum[tid];
  uint4 raw_components;
#pragma clang loop unroll(full)
  for (ushort i = 0; i < 4; ++i) {
    raw_components[i] = components[tid + i * args.batch_stride];
    raw_components[i] = decode_difference(sum[i], raw_components[i]);
  }
  
  MRAtom atom;
#pragma clang loop unroll(full)
  for (ushort dim = 0; dim < 3; ++dim) {
    uint dequantized_i = raw_components[dim] >> 1;
    ushort sign = raw_components[dim] & 1;
    
    float dequantized_f = float(dequantized_i) * args.inverse_scale_factor;
    dequantized_f = select(dequantized_f, -dequantized_f, sign);
    atom.origin[dim] = dequantized_f;
  }
  atom.tailStorage = raw_components[3];
  
  atom.store(atoms + tid);
  cumulativeSum[tid] = raw_components;
}


