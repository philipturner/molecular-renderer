enum GeneralCountersRegion {
  // removeProcess2 + removeProcess3
  case atomsRemovedVoxelCount
  
  // removeProcess4
  case vacantSlotCount
  
  // addProcess2
  case allocatedSlotCount
  
  // removeProcess1 + removeProcess2
  case rebuiltVoxelCount
  
  // Offset (in bytes) of the region's start.
  var offset: Int {
    fatalError("Not implemented")
  }
}

// A play on "General Nanomedics" from the Nanofactory Corporation LOL.
struct GeneralCounters {
  static var totalSize: Int { 256 * 4 }
}
