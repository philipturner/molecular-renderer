extension RemoveProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // write to group.rebuiltMarks
  // scan for voxels with atoms removed
  // create compact list of these voxels (SIMD + global reduction)
  // global counter is the indirect dispatch argument
  // write to sparse.atomsRemovedVoxelIDs
  //
  // createSource2
}
