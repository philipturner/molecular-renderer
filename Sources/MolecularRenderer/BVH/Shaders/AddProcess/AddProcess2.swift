extension AddProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // write to group.rebuiltMarks
  // scan for voxels with atoms added
  // prefix sum over the 8 counters within the voxel
  // if atoms were added, write to dense.rebuiltMarks
  // otherwise, mask out future operations for this SIMD lane
  //
  // read from dense.assignedSlotIDs
  // if a slot hasn't been assigned yet
  //   allocate new voxels (SIMD + global reduction)
  //   if exceeded memory slot limit, crash w/ diagnostic info
  //
  // add existing atom count to prefix-summed 8 counters
  // write to dense.atomicCounters
  // if new atom count is too large, crash w/ diagnostic info
  // write new atom count into memory slot header
  //
  // createSource2
}
