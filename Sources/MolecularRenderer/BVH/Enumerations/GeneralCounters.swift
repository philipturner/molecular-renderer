enum GeneralCountersRegion {
  // removeProcess2 + removeProcess3
  case atomsRemovedVoxelCount
  
  // removeProcess4
  case vacantSlotCount
  
  // addProcess2
  case allocatedSlotCount
  
  // removeProcess1 + removeProcess2
  case rebuiltVoxelCount
}

// A play on "General Nanomedics" from the Nanofactory Corporation LOL.
struct GeneralCounters {
  // Offset (in bytes) of the region's start.
  static func offset(_ region: GeneralCountersRegion) -> Int {
    switch region {
    case .atomsRemovedVoxelCount:
      return 0
    case .vacantSlotCount:
      return 16
    case .allocatedSlotCount:
      return 16 + 4
    case .rebuiltVoxelCount:
      return 16 + 4 + 4
    }
  }
  
  static var totalSize: Int {
    var output: Int = .zero
    output += 16
    output += 4
    output += 4
    output += 16
    return output
  }
}
