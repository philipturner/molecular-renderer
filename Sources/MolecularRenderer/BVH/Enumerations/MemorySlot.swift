// Fixed chunk of memory for each voxel to store its data.
enum MemorySlot {
  // per 2 nm voxel header
  // per 0.25 nm voxel headers
  case header
  
  // 2 nm -> global references
  case reference32
  
  // 0.25 nm -> 2 nm references
  case reference16
  
  // Size (in bytes) of the memory slot.
  var size: Int {
    switch self {
    case .header:
      return (2 + 512) * 4
    case .reference32:
      return 3072 * 4
    case .reference16:
      return 20480 * 2
    }
  }
  
  // The largest slot ID before 64-bit integers must be
  // used to index into this buffer.
  var max32BitSlotID: Int {
    switch self {
    case .header:
      return 4_000_000_000 / (2 + 512)
    case .reference32:
      return 4_000_000_000 / 3072
    case .reference16:
      return 4_000_000_000 / 20480
    }
  }

  // Offset (in bytes) of the small headers within a header slot.
  static var smallHeadersOffset: Int { 2 * 4 }
}
