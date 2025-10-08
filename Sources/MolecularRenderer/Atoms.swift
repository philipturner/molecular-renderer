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
  
  // This ergonomic Swift API is not the CPU-side bottleneck! Very well done.
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
  struct Transaction {
    var removedIDs: [UInt32] = []
    var movedIDs: [UInt32] = []
    var movedPositions: [SIMD4<Float>] = []
    var addedIDs: [UInt32] = []
    var addedPositions: [SIMD4<Float>] = []
  }
  
  // TODO: Attempt to optimize this with multithreading + merging the memory
  // allocations for movedAtoms and addedAtoms + writing positions directly to
  // the GPU buffer. It consumes up to 57% of the CPU-side latency per atom per
  // frame.
  //
  // We don't expect 1M atoms/frame to be a reasonable target for GPU-side
  // performance, so this optimization isn't critical. It will be deferred to a
  // future PR.
  
  // 0.1M atoms/frame
  //
  // | CPU-side contributor | macOS    | Windows  |
  // | -------------------- | -------- | -------- |
  // |                      | ns/atom  | ns/atom  |
  // | API usage            | 2.44E-09 | 5.41E-09 |
  // | register transaction | 2.93E-09 | 8.98E-09 |
  // | memcpy to GPU buffer | 3.30E-10 | 2.57E-09 |
  // | total                | 5.70E-09 | 1.70E-08 |
  // | latency (ms)         | 0.570    | 1.696    |
  
  // 1M atoms/frame
  //
  // | CPU-side contributor | macOS    | Windows  |
  // | -------------------- | -------- | -------- |
  // |                      | ns/atom  | ns/atom  |
  // | API usage            | 2.32E-09 | 5.28E-09 |
  // | register transaction | 3.90E-09 | 7.74E-09 |
  // | memcpy to GPU buffer | 5.44E-10 | 2.02E-09 |
  // | total                | 6.76E-09 | 1.50E-08 |
  // | latency (ms)         | 6.764    | 15.040   |
  
  // 100M address space size
  //
  // | Block Size | macOS     | Windows   |
  // | ---------- | --------- | --------- |
  // |            | s/address | s/address |
  // | 256        | 1.30E-12  | 1.86E-12  |
  // | 512        | 6.50E-13  | 9.90E-13  |
  // | 1024       | 3.30E-13  | 5.50E-13  |
  //
  // | Block Size | macOS | Windows |
  // | ---------- | ----- | ------- |
  // |            | ms    | ms      |
  // | 256        | 0.130 | 0.186   |
  // | 512        | 0.065 | 0.099   |
  // | 1024       | 0.033 | 0.055   |
  
  // GPU is reaching 78-80% PCIe utilization, with PCIe 3 x16 = 15.76 GB/s.
  // That means 1.61 ns/atom (0.1M atoms), 1.59 ns/atom (1M atoms) on the GPU
  // timeline.
  func registerChanges() -> Transaction {
    var modifiedBlockIDs: [UInt32] = []
    for blockID in 0..<(addressSpaceSize / Self.blockSize) {
      // Reset blocksModified
      guard blocksModified[blockID] else {
        continue
      }
      blocksModified[blockID] = false
      
      modifiedBlockIDs.append(UInt32(blockID))
    }
    
    // Reserve array capacity to defeat overhead of array re-allocation.
    let maxAtomCount = modifiedBlockIDs.count * Self.blockSize
    var output = Transaction()
    output.removedIDs.reserveCapacity(maxAtomCount)
    output.movedIDs.reserveCapacity(maxAtomCount)
    output.movedPositions.reserveCapacity(maxAtomCount)
    output.addedIDs.reserveCapacity(maxAtomCount)
    output.addedPositions.reserveCapacity(maxAtomCount)
    
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
