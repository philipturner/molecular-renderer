// Tasks:
// - Flesh out the notion of transactions (.add, .remove, .move, none) and
//   how they materialize on the CPU-side API. [DONE]
// - Add 'application.atoms' into the public API, as well as its initialization
//   process. Not yet implementing the heuristic that chooses atom count based
//   on a partitioning of GPU memory. Nonetheless, the API goes by a mapping
//   of allocated memory -> number of atom blocks able to hold. This establishes
//   the future anticipation of not directly specifying max atom count. [DONE]
// - Simply compile the transactions into a linear list of atoms as the
//   "acceleration structure" for now.
// - Create a simple test that switches between isopropanol and methane to
//   demonstrate correct functioning of .add and .remove.

public class Atoms {
  public let addressSpaceSize: Int
  private static let blockSize: Int = 512
  
  private let positions: UnsafeMutablePointer<SIMD4<Float>>
  private let previousOccupied: UnsafeMutablePointer<Bool>
  private let occupied: UnsafeMutablePointer<Bool>
  private let positionsModified: UnsafeMutablePointer<Bool>
  private let blocksModified: UnsafeMutablePointer<Bool>
  
  init(allocationSize: Int) {
    let allocationAtomCount = allocationSize / 16
    let allocationBlockCount = allocationAtomCount / Self.blockSize
    guard allocationBlockCount > 0 else {
      fatalError("Allocation could not hold any atoms.")
    }
    self.addressSpaceSize = allocationBlockCount * Self.blockSize
    
    self.positions = .allocate(capacity: addressSpaceSize)
    self.previousOccupied = .allocate(capacity: addressSpaceSize)
    self.occupied = .allocate(capacity: addressSpaceSize)
    self.positionsModified = .allocate(capacity: addressSpaceSize)
    self.blocksModified = .allocate(capacity: allocationBlockCount)
    
    // Clear the initial values of all buffers.
    previousOccupied.initialize(repeating: false, count: addressSpaceSize)
    occupied.initialize(repeating: false, count: addressSpaceSize)
    positionsModified.initialize(repeating: false, count: addressSpaceSize)
    blocksModified.initialize(repeating: false, count: allocationBlockCount)
  }
  
  deinit {
    positions.deallocate()
    previousOccupied.deallocate()
    occupied.deallocate()
    positionsModified.deallocate()
    blocksModified.deallocate()
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
  
  // Changes to the acceleration structure in a single frame.
  public struct Transaction {
    public var removedIDs: [UInt32] = []
    public var movedIDs: [UInt32] = []
    public var movedPositions: [SIMD4<Float>] = []
    public var addedIDs: [UInt32] = []
    public var addedPositions: [SIMD4<Float>] = []
  }
  
  // Acceleration structure building is scripted from the public API for now.
  public func registerChanges() -> Transaction {
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
          let position = positions[Int(atomID)]
          
          if atomPreviousOccupied {
            output.movedIDs.append(atomID)
            output.movedPositions.append(position)
          } else {
            output.addedIDs.append(atomID)
            output.addedPositions.append(position)
          }
        }
      }
    }
    
    return output
  }
}
