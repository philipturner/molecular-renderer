enum MemorySlotRegion: CaseIterable {
  // per 2 nm voxel header
  case headerLarge
  
  // per 0.25 nm voxel header
  case headerSmall
  
  // 2 nm -> global references
  case referenceLarge
  
  // 0.25 nm -> 2 nm references
  case referenceSmall
}

struct MemorySlot {
  // Offset (in bytes) of the region's start.
  static func offset(_ region: MemorySlotRegion) -> Int {
    switch region {
    case .headerLarge:
      return 0
    case .headerSmall:
      return 8
    case .referenceLarge:
      return 8 + 512 * 4
    case .referenceSmall:
      return 8 + 512 * 4 + 3072 * 4
    }
  }
  
  static var totalSize: Int {
    var output: Int = .zero
    output += 8
    output += 512 * 4
    output += 3072 * 4
    output += 20480 * 2
    return output
  }
}
