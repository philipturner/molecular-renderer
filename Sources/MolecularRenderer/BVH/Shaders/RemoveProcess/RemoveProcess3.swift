extension RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch indirect groups SIMD3(atomic counter, 1, 1)
  //
  // check the occupiedMark of each atom in voxel
  //   if either 0 or 2, remove from the list
  // prefix sum to compact the reference list (SIMD + group reduction)
  // write to sparse.memorySlots in-place, sanitized to 128 atoms at a time
  //
  // if atoms remain, write to dense.rebuiltMarks
  // otherwise, reset entry in dense.assignedSlotIDs and sparse.assignedVoxelIDs
  //
  // createSource3
}
