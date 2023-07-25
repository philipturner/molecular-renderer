//
//  Serialization.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/23/23.
//

#include <metal_stdlib>
#include "../Utilities/MRAtom.metal"
using namespace metal;

#define SERIALIZATION_MEMORY_COALESCING 2
#define TRANSACTION vec<ushort, SERIALIZATION_MEMORY_COALESCING>

// TODO: Allow the data to be compressed with higher efficiency by dropping
// several bits off the mantissa. If an atom moves 0.25 nm/frame, here are
// bits/position component at specific precisions:
// - 9 bits: 1 pm
// - 8 bits: 2 pm
// - 7 bits: 4 pm
// - 6 bits: 8 pm
// - 5 bits: 16 pm
// - 4 bits: 33 pm
// - 3 bits: 63 pm
// - 2 bits: 125 pm
// - 1 bit:  250 pm
//
// TODO: Save a checkpoint every N frames for recovery from corruption and
// replaying from the middle of the recording. The distance between each
// checkpoint should be specified in the header. The delta for checkpointed
// frames should still be stored, so you can trace backward from such frames
// (halving the required checkpointing resolution).

kernel void serialize
(
 device ushort *output [[buffer(0)]],
 device uint4 *cumulativeSum [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 constant uint &batch_stride [[buffer(3)]],
 
 uint tid [[thread_position_in_grid]])
{
  uint cursor = SERIALIZATION_MEMORY_COALESCING * tid;
  TRANSACTION mantissas[3];
  TRANSACTION exponents[3];
  TRANSACTION flags;
  
#pragma clang loop unroll(full)
  for (ushort i = 0; i < SERIALIZATION_MEMORY_COALESCING; ++i) {
    MRAtom atom(atoms + cursor);
    uint4 previous = cumulativeSum[cursor];
    
#pragma clang loop unroll(full)
    for (ushort dim = 0; dim < 3; ++dim) {
      float quantized_f = rint(atom.origin[dim] * 1024);
      uint quantized_i = uint(abs(quantized_f));
      quantized_i = (quantized_i << 1) + ushort(quantized_f < 0);
      atom.origin[dim] = as_type<uint>(quantized_i);
      
      quantized_i = quantized_i - previous[dim];
      ushort2 parts = as_type<ushort2>(quantized_i);
      mantissas[dim][i] = parts[0];
      exponents[dim][i] = parts[1];
    }
    
    flags[i] = atom.tailStorage - ushort(previous[4]);
    atom.store((device MRAtom*)(cumulativeSum + cursor));
    cursor += 1;
  }
  cursor -= SERIALIZATION_MEMORY_COALESCING;
  
#pragma clang loop unroll(full)
  for (ushort dim = 0; dim < 3; ++dim) {
    *(device TRANSACTION*)(output + cursor) = mantissas[dim];
    cursor += batch_stride;
    
    *(device TRANSACTION*)(output + cursor) = exponents[dim];
    cursor += batch_stride;
  }
  *(device TRANSACTION*)(output + cursor) = flags;
}

kernel void deserialize
(
 device ushort *input [[buffer(0)]],
 device uint4 *cumulativeSum [[buffer(1)]],
 device MRAtom *atoms [[buffer(2)]],
 constant uint &batch_stride [[buffer(3)]],
 
 uint tid [[thread_position_in_grid]])
{
  uint cursor = SERIALIZATION_MEMORY_COALESCING * tid;
  TRANSACTION mantissas[3];
  TRANSACTION exponents[3];
  TRANSACTION flags;
  
#pragma clang loop unroll(full)
  for (ushort dim = 0; dim < 3; ++dim) {
    mantissas[dim] = *(device TRANSACTION*)(input + cursor);
    cursor += batch_stride;
    
    exponents[dim] = *(device TRANSACTION*)(input + cursor);
    cursor += batch_stride;
  }
  flags = *(device TRANSACTION*)(input + cursor);
  
  cursor = SERIALIZATION_MEMORY_COALESCING * tid;
#pragma clang loop unroll(full)
  for (ushort i = 0; i < SERIALIZATION_MEMORY_COALESCING; ++i) {
    MRAtom atom((device MRAtom*)(cumulativeSum + cursor));
    uint4 next;
    
#pragma clang loop unroll(full)
    for (ushort dim = 0; dim < 3; ++dim) {
      ushort2 parts;
      parts[0] = mantissas[dim][i];
      parts[1] = exponents[dim][i];
      
      uint previous = as_type<uint>(atom.origin[dim]);
      uint quantized_i = previous + as_type<uint>(parts);
      next[dim] = quantized_i;
      
      ushort sign = quantized_i & 1;
      quantized_i >>= 1;
      float quantized_f = float(quantized_i) / 1024;
      quantized_f = select(quantized_f, -quantized_f, sign);
      atom.origin[dim] = quantized_f;
    }
    
    atom.tailStorage += flags[i];
    next[3] = atom.tailStorage;
    
    cumulativeSum[cursor] = next;
    atom.store(atoms + cursor);
    cursor += 1;
  }
}

