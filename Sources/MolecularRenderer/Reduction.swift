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
  
  static func threadgroupSumPrimitive(offset: Int) -> String {
    return """
    {
      uint input = 0;
      if (localID < 4) {
        input = threadgroupMemory[\(offset) + localID];
      }
      \(Reduction.barrier())
    }
    """
  }
}
