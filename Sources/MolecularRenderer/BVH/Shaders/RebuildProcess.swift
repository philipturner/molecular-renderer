struct RebuildProcess {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 2)
  // dispatch groups  SIMD3(repeating: worldDimension / 8)
  //
  // requirements
  //   generate sparse.rebuiltVoxelIDs
  //   generate indirect dispatch arguments for next kernel
  //   set group.occupiedMarks for BVH traversal
  //
  // createSource1
  
  // For the massive fused GPU kernel, write out what happens during each of
  // the 4 stages, just like you do for RemoveProcess and AddProcess.
}
