extension RemoveProcess {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(memorySlotCount, 1, 1)
  // threadgroup memory 16 B
  //
  // scan for slots with no assigned voxel
  // create compact list of these slots (SIMD + group + global reduction)
  // write to sparse.vacantSlotIDs
  //
  // createSource4
}
