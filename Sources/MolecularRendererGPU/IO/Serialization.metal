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

// Run a concurrent Metal compute command for each simulation in the batch,
// instead of making a lookup table.

kernel void serialize
(
 device MRAtom *atoms [[buffer(0)]],
 device ushort *output [[buffer(1)]],
 constant uint &batch_stride [[buffer(2)]],
 
 uint tid [[thread_position_in_grid]])
{
  uint cursor = SERIALIZATION_MEMORY_COALESCING * tid;
  TRANSACTION mantissas[3];
  TRANSACTION exponents[3];
  TRANSACTION flags;
  
#pragma clang loop unroll(full)
  for (ushort i = 0; i < SERIALIZATION_MEMORY_COALESCING; ++i) {
    MRAtom atom(atoms + cursor + i);
    flags[i] = atom.tailStorage;
    
#pragma clang loop unroll(full)
    for (ushort dim = 0; dim < 3; ++dim) {
      float quantized_f = rint(atom.origin[dim] * 1024);
      uint quantized_i = uint(abs(quantized_f));
      quantized_i = (quantized_i << 1) + ushort(quantized_f < 0);
      
      ushort2 parts = as_type<ushort2>(quantized_i);
      mantissas[dim][i] = parts[0];
      exponents[dim][i] = parts[1];
    }
  }
  
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
 device MRAtom *atoms [[buffer(0)]],
 device ushort *input [[buffer(1)]],
 constant uint &batch_stride [[buffer(2)]],
 
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
    MRAtom atom;
    atom.tailStorage = flags[i];
    
#pragma clang loop unroll(full)
    for (ushort dim = 0; dim < 3; ++dim) {
      ushort sign = mantissas[dim][i] & 1;
      ushort2 parts;
      parts[0] = mantissas[dim][i];
      parts[1] = exponents[dim][i];
      
      uint quantized_i = as_type<uint>(parts);
      quantized_i >>= 1;
      float quantized_f = float(quantized_i) / 1024;
      quantized_f = select(quantized_f, -quantized_f, sign);
      atom.origin[dim] = quantized_f;
    }
    
    atom.store(atoms + cursor + i);
  }
}
