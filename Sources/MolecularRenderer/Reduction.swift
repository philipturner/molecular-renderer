// Utility functions for reductions on the GPU.
struct Reduction {
  // WARNING: Avoid barriers in areas not accessed by every thread in the
  // group. In this situation, behavior is nominally undefined.
  static func barrier() -> String {
    #if os(macOS)
    "threadgroup_barrier(mem_flags::mem_threadgroup);"
    #else
    "GroupMemoryBarrierWithGroupSync();"
    #endif
  }
  
  static func waveActiveCountBits(_ input: String) -> String {
    #if os(macOS)
    "popcount(uint(uint64_t(simd_ballot(\(input)))))"
    #else
    "WaveActiveCountBits(\(input))"
    #endif
  }
  
  static func wavePrefixSum(_ input: String) -> String {
    #if os(macOS)
    "simd_prefix_exclusive_sum(\(input))"
    #else
    "WavePrefixSum(\(input))"
    #endif
  }
  
  static func waveReadLaneAt(_ input: String, laneID: Int) -> String {
    #if os(macOS)
    "simd_broadcast(\(input), \(laneID))"
    #else
    "WaveReadLaneAt(\(input), \(laneID))"
    #endif
  }
  
  static func waveIsFirstLane() -> String {
    #if os(macOS)
    "simd_is_first()"
    #else
    "WaveIsFirstLane()"
    #endif
  }
  
  static func threadgroupSumPrimitive(offset: Int) -> String {
    """
    {
      uint input = 0;
      if (localID < 4) {
        input = threadgroupMemory[\(offset) + localID];
      }
      \(Reduction.barrier())
      
      if (localID < 32) {
        uint prefixSum = \(Reduction.wavePrefixSum("input"));
        uint inclusiveSum = prefixSum + input;
        uint totalSum =
        \(Reduction.waveReadLaneAt("inclusiveSum", laneID: 3));
        
        if (localID < 4) {
          threadgroupMemory[\(offset) + localID] = prefixSum;
        }
        threadgroupMemory[\(offset) + 4] = totalSum;
      }
      \(Reduction.barrier())
    }
    """
  }
  
  static func atomicFetchAdd(
    buffer: String,
    address: String,
    operand: String,
    output: String
  ) -> String {
    #if os(macOS)
    """
    \(output) = atomic_fetch_add_explicit(
      \(buffer) + \(address), // object
      \(operand), // operand
      memory_order_relaxed); // order
    """
    #else
    """
    InterlockedAdd(
      \(buffer)[\(address)], // dest
      \(operand), // value
      \(output)); // original_value
    """
    #endif
  }
}
