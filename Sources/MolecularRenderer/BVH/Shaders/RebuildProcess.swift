struct RebuildProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // scan for rebuilt voxels
  // create a compact list of these voxels (SIMD + global reduction)
  // global counter is the indirect dispatch argument
  // write to sparse.rebuiltVoxelIDs
  //
  // read from dense.assignedSlotIDs
  //   do not use any optimizations to reduce the bandwidth cost
  // write to group.occupiedMarks
  //
  // createSource1
  
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
  //
  //
  // # Phase IV
  //
  // restore the prefix sum result
  func createSource2() -> String {
    fatalError("Not implemented.")
  }
}
