extension AddProcess {
  // [numthreads(128, 1, 1)]
  // dispatch threads SIMD3(movedCount + addedCount, 1, 1)
  //
  // read atom from address space
  // restore the relativeOffsets
  // read from dense.atomicCounters
  //   add to relativeOffset, generating the correct offset
  // read from dense.assignedSlotIDs
  // write a 32-bit reference into sparse.memorySlots
  //
  // createSource3
}
