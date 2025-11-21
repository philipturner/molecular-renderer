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
  
  // The first slot ID where 64-bit integers must be
  // used to index into this buffer.
  var max32BitSlotCount: Int {
    switch self {
    case .header:
      return 4_000_000_000 / (2 + 512)
    case .reference32:
      return 4_000_000_000 / 3072
    case .reference16:
      #if os(macOS)
      return 4_000_000_000 / 20480
      #else
      // 2 billion, but 1.5 billion for debugging
      return 1_500_000_000 / 20480
      #endif
    }
  }

  // Response to the overflow problem:
  // Branch that only activates when voxelAllocationSize is
  // large enough to cause an overflow for references16 (~11 GB).
  //
  // Windows:
  // Bind multiple versions of references16 into the shader. We must use
  // a descriptor table with multiple entries, and properly address
  // the NonUniformResourceIndex problem. With 32 GB of RAM, 6 versions
  // of references16 would be bound.
  //
  // macOS:
  // Modify RemoveProcess3, AddProcess3, RebuildProcess2, Render to
  // use some form of 64-bit arithmetic. When possible, store pointers
  // in shader registers with the 64-bit offset already applied.
  // 
  // The solution will scale to 430-460 GB of RAM, as we won't account
  // for 32-bit overflows of '.header'. This will pose some scaling
  // issues if we implement the more memory-efficient BVH structure.
  
  // Offset (in bytes) of the small headers within a header slot.
  static var smallHeadersOffset: Int { 2 * 4 }
}
