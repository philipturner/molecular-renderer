//
//  FaultCounter.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/15/23.
//

#ifndef FAULT_COUNTER_H
#define FAULT_COUNTER_H

#include <metal_stdlib>
#include "Constants.metal"
using namespace metal;

#if FAULT_COUNTERS_ENABLE
#define FAULT_COUNTER_RETURN(COUNTER) \
if (COUNTER.quit()) { \
return; \
} \

#else
#define FAULT_COUNTER_RETURN(COUNTER) \

#endif

class FaultCounter {
#if FAULT_COUNTERS_ENABLE
  uint counter;
  uint tolerance;
#endif
  
public:
  FaultCounter(uint tolerance) {
#if FAULT_COUNTERS_ENABLE
    this->counter = 0;
    this->tolerance = tolerance;
#endif
  }
  
  bool quit() {
#if FAULT_COUNTERS_ENABLE
    counter += 1;
    return (counter > tolerance);
#else
    return false;
#endif
  }
};

#endif
