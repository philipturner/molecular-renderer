//
//  Atomic.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
//

#ifndef MR_ATOMIC_H
#define MR_ATOMIC_H

#include <metal_stdlib>
using namespace metal;

#define atomic_compare_exchange(OBJECT, EXPECTED, DESIRED) \
atomic_compare_exchange_weak_explicit(OBJECT, EXPECTED, DESIRED, memory_order_relaxed, memory_order_relaxed) \

#define atomic_fetch_add(OBJECT, OPERAND) \
atomic_fetch_add_explicit(OBJECT, OPERAND, memory_order_relaxed) \

#endif
