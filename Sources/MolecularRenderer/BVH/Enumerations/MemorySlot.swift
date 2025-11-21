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

  // Response to the overflow problem:
  // Branch that only activates when voxelAllocationSize is
  // large enough to cause an overflow for references16 (~11 GB).
  //
  // Windows:
  // Bind 6-12 versions of references16 into the shader. We must use
  // a descriptor table with multiple entries, and properly address
  // the NonUniformResourceIndex problem. This solution scales up to
  // 64 GB of RAM. Existing GPUs max out at 32 GB.
  //
  // macOS:
  // Modify RemoveProcess3, AddProcess3, RebuildProcess2, Render to
  // use some form of 64-bit arithmetic. When possible, store pointers
  // in shader registers with the 64-bit offset already applied.

  // Offset (in bytes) of the small headers within a header slot.
  static var smallHeadersOffset: Int { 2 * 4 }
}
