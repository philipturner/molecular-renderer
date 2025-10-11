struct GarbageCollect {
  static func createSource(memorySlotCount: Int) -> String {
    // Per dense voxel
    //   memorySlotIDs - initialize to UInt32.max with shader
    //
    // Per sparse voxel
    //   assignedVoxelIDs - initialize to UInt32.max with shader
    //   vacantSlotIDs - purge to UInt32.max before every frame
    fatalError("Not implemented.")
  }
}
