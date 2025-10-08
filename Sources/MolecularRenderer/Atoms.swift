public class Atoms {
  public let addressSpaceSize: Int
  private static let blockSize: Int = 512
  
  private let positions: UnsafeMutablePointer<SIMD4<Float>>
  private let previousOccupied: UnsafeMutablePointer<Bool>
  private let occupied: UnsafeMutablePointer<Bool>
  private let positionsModified: UnsafeMutablePointer<Bool>
  private let blocksModified: UnsafeMutablePointer<Bool>
  
  init(addressSpaceSize originalAddressSpaceSize: Int) {
    addressSpaceSize = Self.createReducedAddressSpaceSize(
      original: originalAddressSpaceSize)
    guard addressSpaceSize % Self.blockSize == 0 else {
      fatalError("Address space size was not divisible by block size.")
    }
    guard addressSpaceSize > 0 else {
      fatalError("Address space size was zero.")
    }
    
    self.positions = .allocate(capacity: addressSpaceSize)
    self.previousOccupied = .allocate(capacity: addressSpaceSize)
    self.occupied = .allocate(capacity: addressSpaceSize)
    self.positionsModified = .allocate(capacity: addressSpaceSize)
    self.blocksModified = .allocate(capacity: addressSpaceSize / Self.blockSize)
    
    // Clear the initial values of all buffers.
    previousOccupied.initialize(repeating: false, count: addressSpaceSize)
    occupied.initialize(repeating: false, count: addressSpaceSize)
    positionsModified.initialize(repeating: false, count: addressSpaceSize)
    blocksModified.initialize(repeating: false, count: addressSpaceSize / Self.blockSize)
  }
  
  deinit {
    positions.deallocate()
    previousOccupied.deallocate()
    occupied.deallocate()
    positionsModified.deallocate()
    blocksModified.deallocate()
  }
  
  static func createReducedAddressSpaceSize(original: Int) -> Int {
    var output = original / Self.blockSize
    output *= Self.blockSize
    return output
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
  // TODO: Remove public modifier when done debugging.
  public struct Transaction {
    public var removedIDs: [UInt32] = []
    public var movedIDs: [UInt32] = []
    public var movedPositions: [SIMD4<Float>] = []
    public var addedIDs: [UInt32] = []
    public var addedPositions: [SIMD4<Float>] = []
  }
  
  public func registerChanges() -> Transaction {
    var modifiedBlockIDs: [UInt32] = []
    modifiedBlockIDs.reserveCapacity(addressSpaceSize / Self.blockSize)
    for blockID in 0..<(addressSpaceSize / Self.blockSize) {
      // Reset blocksModified
      guard blocksModified[blockID] else {
        continue
      }
      blocksModified[blockID] = false
      
      modifiedBlockIDs.append(UInt32(blockID))
    }
    
    var output = Transaction()
    for blockID in modifiedBlockIDs {
      let startAtomID = blockID * UInt32(Self.blockSize)
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
