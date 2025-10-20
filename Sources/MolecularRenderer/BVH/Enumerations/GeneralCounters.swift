// TODO: Remove public modifier after debugging. Remove from all places where
// it appears in this file.
public enum GeneralCountersRegion: Int, CaseIterable {
  // dispatch removeProcess2
  case atomsRemovedGroupCount = 0
  
  // dispatch removeProcess3
  case atomsRemovedVoxelCount
  
  // removeProcess4
  case vacantSlotCount
  
  // dispatch addProcess2
  case addedGroupCount
  
  // addProcess2
  case allocatedSlotCount
  
  // dispatch rebuildProcess1
  case rebuiltGroupCount
  
  // dispatch rebuildProcess2
  case rebuiltVoxelCount
  
  // dispatch resetVoxelMarks
  case resetGroupCount
  
  public var size: Int {
    switch self {
    case .vacantSlotCount:
      return 4
    case .allocatedSlotCount:
      return 4
    default:
      return 16
    }
  }
}

// Container for several small counters involved in global reductions.
public struct GeneralCounters {
  // Offset (in bytes) of the region's start.
  public static func offset(_ region: GeneralCountersRegion) -> Int {
    let rawValue = region.rawValue
    
    var output: Int = .zero
    for otherRawValue in 0..<rawValue {
      let otherRegion = GeneralCountersRegion(rawValue: otherRawValue)!
      output += otherRegion.size
    }
    return output
  }
  
  public static var totalSize: Int {
    var output: Int = .zero
    for region in GeneralCountersRegion.allCases {
      output += region.size
    }
    return output
  }
}
