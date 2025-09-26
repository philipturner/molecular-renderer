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

// Changes to the acceleration structure in a single frame.
struct Transaction {
  var removedIDs: [UInt32] = []
  var movedIDs: [UInt32] = []
  var movedPositions: [SIMD4<Float>] = []
  var addedIDs: [UInt32] = []
  var addedPositions: [SIMD4<Float>] = []
}

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
  
  // This is probably a bottleneck in CPU-side code (1 function call for
  // each access in -Xswiftc -Ounchecked). We can work around this by
  // introducing an API for modifying subranges at a time.
  public subscript(index: Int) -> SIMD4<Float>? {
    get {
      if occupied[index] {
        return positions[index]
      } else {
        return nil
      }
    }
    set {
      blocksModified[index / Self.blockSize] = true
      positionsModified[index] = true
      
      if let newValue {
        occupied[index] = true
        positions[index] = newValue
      } else {
        occupied[index] = false
      }
    }
  }
  
  // There will be another function that resets the pointers at modified blocks
  // (migrate current occupied to previous occupied, clear positionsModified).
  // This function should simultaneously output a set of transactions. The
  // transactions can be scoped to per individual atom. Ideally, they would
  // be sorted too. The GPU likes to know the atoms to remove, then the atoms
  // to add, in that exact order.
  //
  // Order:
  // .remove
  // .move (GPU recognizes as part of both remove and add sub-tasks)
  // .add
  func registerChanges() -> Transaction {
    var output = Transaction()
    for blockID in 0..<(addressSpaceSize / Self.blockSize) {
      // Reset blocksModified
      guard blocksModified[blockID] else {
        continue
      }
      blocksModified[blockID] = false
      
      let startAtomID = UInt32(blockID * Self.blockSize)
      let endAtomID = startAtomID + UInt32(Self.blockSize)
      for atomID in startAtomID..<endAtomID {
        // Reset positionsModified
        guard positionsModified[Int(atomID)] else {
          continue
        }
        positionsModified[Int(atomID)] = false
        
        // Read occupied
        let atomPreviousOccupied = previousOccupied[Int(atomID)]
        let atomOccupied = occupied[Int(atomID)]
        
        // Save changes to previousOccupied
        previousOccupied[Int(atomID)] = atomOccupied
        
        if !atomOccupied {
          if atomPreviousOccupied {
            output.removedIDs.append(atomID)
          }
        } else {
          // Read positions
        }
      }
    }
    
    fatalError("Not implemented.")
  }
}
