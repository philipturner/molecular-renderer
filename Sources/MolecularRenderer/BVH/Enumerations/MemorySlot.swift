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
  // Bind 6 versions of references16 into the shader. AMD drivers
  // cannot dynamically index into an array of resources
  // (NonUniformResourceIndex problem), so don't pretend they do.
  // This scales up to 64 GB of RAM. Existing GPUs max out at 32 GB.
  //
  // > Will likely need to revise the plans on Windows. First, check
  // > whether the basic idea even works.

  // Offset (in bytes) of the small headers within a header slot.
  static var smallHeadersOffset: Int { 2 * 4 }
}
