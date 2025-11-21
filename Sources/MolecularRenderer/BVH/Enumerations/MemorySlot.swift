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
    // Total size: 55304 B
    //
    // 32-bit overflow conditions annotated:
    switch self {
    case .header:
      // slotID = 8_355_967.502
      // voxelAllocationSize = 462_118_000_000
      return (2 + 512) * 4
    case .reference32:
      // slotID = 1_398_101.333
      // voxelAllocationSize = 77_320_000_000
      return 3072 * 4
    case .reference16:
      // slotID = 209_712.200
      // voxelAllocationSize = 11_598_000_000
      return 20480 * 2
    }
  }
  
  // Offset (in bytes) of the small headers within a header slot.
  static var smallHeadersOffset: Int { 2 * 4 }
}
