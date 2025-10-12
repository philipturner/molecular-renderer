extension RebuildProcess {
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  //
  // # Phase I
  //
  // loop over the cuboid bounding box of each atom
  // atomically accumulate into threadgroupCounters
  //
  // # Phase II
  //
  // prefix sum over 512 small voxels (SIMD + group reduction)
  //   read 4 voxels in a single instruction, on 128 threads in parallel
  //   save the prefix sum result for Phase IV
  // if reference count is too large, crash w/ diagnostic info
  // write reference count into memory slot header
  //
  // # Phase III
  //
  // loop over a 3x3x3 grid of small voxels for each atom
  // run the cube-sphere test and mask out voxels outside the 2 nm bound
  // atomically accumulate into threadgroupCounters
  // write a 16-bit reference to sparse.memorySlots
  //
  // # Phase IV
  //
  // restore the prefix sum result
  // read end of reference list from threadgroupCounters
  // if atom count is zero, output UInt32(0)
  // otherwise
  //   store two offsets relative to the slot's region for 16-bit references
  //   compress these two 16-bit offsets into a 32-bit word
  func createSource2() -> String {
    fatalError("Not implemented.")
  }
}
