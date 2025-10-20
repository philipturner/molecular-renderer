enum GeneralCountersRegion: Int, CaseIterable {
  // removeProcess2 + removeProcess3
  case atomsRemovedVoxelCount = 0
  
  // removeProcess4
  case vacantSlotCount = 1
  
  // addProcess2
  case allocatedSlotCount = 2
  
  // rebuildProcess1 + rebuildProcess2
  case rebuiltVoxelCount = 3
  
  var size: Int {
    switch self {
    case .atomsRemovedVoxelCount:
      return 16
    case .vacantSlotCount:
      return 4
    case .allocatedSlotCount:
      return 4
    case .rebuiltVoxelCount:
      return 16
    }
  }
}

// Container for several small counters involved in global reductions.
struct GeneralCounters {
  // Offset (in bytes) of the region's start.
  static func offset(_ region: GeneralCountersRegion) -> Int {
    let rawValue = region.rawValue
    
    var output: Int = .zero
    for otherRawValue in 0..<rawValue {
      let otherRegion = GeneralCountersRegion(rawValue: otherRawValue)!
      output += otherRegion.size
    }
    return output
  }
  
  static var totalSize: Int {
    var output: Int = .zero
    for region in GeneralCountersRegion.allCases {
      output += region.size
    }
    return output
  }
}
