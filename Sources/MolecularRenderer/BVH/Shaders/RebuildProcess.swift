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
  // # Phase II
  //
  // if reference count is too large, crash w/ diagnostic info
  //
  // # Phase III
  //
  // # Phase IV
  func createSource2() -> String {
    fatalError("Not implemented.")
  }
}
