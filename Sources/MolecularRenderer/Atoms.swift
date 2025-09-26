// Tasks:
// - Flesh out the notion of transactions (.add, .remove, .move, none) and
//   how they materialize on the CPU-side API.
// - Create GPU code to simply compile the transactions into a linear list of
//   atoms as the "acceleration structure" for now.
// - Create a simple test that switches between isopropanol and methane to
//   demonstrate correct functioning of .add and .remove.
//
// First concept: allocating fixed "address space" for atoms at startup
// - atom count determined by GPU memory allocation and partitioning between
//   atoms and voxels
// - for now, just specify CPU-side memory allocation size for
//   'ApplicationDescriptor.allocationSize'
// - create a property to retrieve the maximum atom count:
//   'Application.atoms.addressSpaceSize'
// Second concept: the CPU-side API for entering / modifying atoms
// Third concept: making this CPU-side API computationally efficient

public class Atoms {
  public let addressSpaceSize: Int
  private static let blockSize: Int = 512
  
  private let positions: UnsafeMutablePointer<SIMD4<Float>>
  private let previousOccupied: UnsafeMutablePointer<Bool>
  private let occupied: UnsafeMutablePointer<Bool>
  private let positionsModified: UnsafeMutablePointer<Bool>
  private let blocksModified: UnsafeMutablePointer<Bool>
  
  init() {
    fatalError("Not implemented.")
  }
  
  deinit {
    // TODO: Deallocate all pointers.
    // Write the deinitializer once the implementation has matured / finalized.
  }
}
