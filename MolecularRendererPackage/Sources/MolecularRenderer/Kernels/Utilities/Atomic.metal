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
atomic_compare_exchange_weak_explicit((device atomic_uint*)(OBJECT), EXPECTED, DESIRED, memory_order_relaxed, memory_order_relaxed) \

#define atomic_compare_exchange_(OBJECT, EXPECTED, DESIRED) \
atomic_compare_exchange_weak_explicit((threadgroup atomic_uint*)(OBJECT), EXPECTED, DESIRED, memory_order_relaxed, memory_order_relaxed) \

#define atomic_fetch_add(OBJECT, OPERAND) \
atomic_fetch_add_explicit((device atomic_uint*)(OBJECT), OPERAND, memory_order_relaxed) \

#define atomic_fetch_add_(OBJECT, OPERAND) \
atomic_fetch_add_explicit((threadgroup atomic_uint*)(OBJECT), OPERAND, memory_order_relaxed) \

#define atomic_fetch_or(OBJECT, OPERAND) \
atomic_fetch_or_explicit((device atomic_uint*)(OBJECT), OPERAND, memory_order_relaxed) \

#define atomic_fetch_or_(OBJECT, OPERAND) \
atomic_fetch_or_explicit((threadgroup atomic_uint*)(OBJECT), OPERAND, memory_order_relaxed) \

#define atomic_load(OBJECT) \
atomic_load_explicit((device atomic_uint*)(OBJECT), memory_order_relaxed) \

#define atomic_load_(OBJECT) \
atomic_load_explicit((threadgroup atomic_uint*)(OBJECT), memory_order_relaxed) \

#endif // MR_ATOMIC_H
