import Dispatch

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
  class Transaction {
    var removedCount: UInt32 = .zero
    var addedCount: UInt32 = .zero
    var movedCount: UInt32 = .zero
    
    var removedIDs: UnsafeMutablePointer<UInt32>
    var movedIDs: UnsafeMutablePointer<UInt32>
    var movedPositions: UnsafeMutablePointer<SIMD4<Float>>
    var addedIDs: UnsafeMutablePointer<UInt32>
    var addedPositions: UnsafeMutablePointer<SIMD4<Float>>
    
    init(blockCount: Int) {
      let maxAtomCount = blockCount * Atoms.blockSize
      removedIDs = .allocate(capacity: maxAtomCount)
      movedIDs = .allocate(capacity: maxAtomCount)
      movedPositions = .allocate(capacity: maxAtomCount)
      addedIDs = .allocate(capacity: maxAtomCount)
      addedPositions = .allocate(capacity: maxAtomCount)
    }
    
    deinit {
      removedIDs.deallocate()
      movedIDs.deallocate()
      movedPositions.deallocate()
      addedIDs.deallocate()
      addedPositions.deallocate()
    }
  }
  
  // Originally, this function created the majority of the CPU-side latency.
  // In the rotating beam benchmark, its contribution was 42%. If the rendering
  // cost is zero, CPU-side latency/atom/frame would be the bottleneck holding
  // back the entire application's performance.
  //
  // Therefore, I spent an extra day (Oct 16 2025) during the acceleration
  // structure PR, addressing this problem. I optimized the latency of
  // 'registerChanges()' and 'upload(transaction:)' with multicore CPU
  // parallelism. Here are the results of the development time invested.
  
  // macOS system:
  // - M1 Max (10-core CPU, 32-core GPU)
  // - 120 Hz display
  // - original latency estimate: 9.25 nm/atom
  //   - limited to 0.901M atoms/frame @ 120 Hz,
  //   - GPU time predicted to be 1.52 ms / 8.33 ms
  // - optimized latency estimate: TODO
  //
  // Windows system:
  // - Intel Core i5-4460, GTX 970
  // - 60 Hz display
  // - original latency estimate: 21.16 ns/atom
  //   - limited to 0.788M atoms/frame @ 60 Hz
  //   - GPU time predicted to be 5.78 ms / 16.67 ms
  // - optimized latency estimate: TODO
  //
  // Real-world performance can probably come very close to the limits stated
  // above. While the GPU is occupied with a second demanding task besides
  // updating the BVH, the CPU is not.
  //
  // On macOS, I ran a test of actual performance with an empty render kernel.
  // The Metal Performance HUD showed the 120 FPS target could be sustained at
  // up to beamDepth = 57, or 0.934M atoms/frame. The lower bound to the time
  // reported for the GPU timeline was 3.39 ms. The GPU time is not reliable
  // because the GPU was underclocking. Powermetrics showed 77% duty cycle at
  // the 389 MHz mode and 0% for the other modes, up to 1296 MHz. Power
  // consumption was 2.05 W, but the maximum power I've ever recorded for this
  // chip is 52 W.
  
  // 0.1M atoms/frame
  //
  // | CPU-side contributor | macOS   | Windows |
  // | -------------------- | ------: | ------: |
  // |                      | ns/atom | ns/atom |
  // | rotate animation     |    2.70 |    6.60 |
  // | API usage            |    2.44 |    5.41 |
  // | register transaction |    2.93 |    8.98 |
  // | memcpy to GPU buffer |    0.33 |    2.57 |
  // | total                |    8.40 |   23.56 |
  //
  // | GPU-side contributor | macOS   | Windows |
  // | -------------------- | ------: | ------: |
  // |                      | ns/atom | ns/atom |
  // | PCIe transfer        |    0.00 |    1.61 |
  // | update BVH           |    2.75 |    7.08 |
  // | total                |    2.75 |    7.08 |
  
  // 1M atoms/frame
  //
  // | CPU-side contributor | macOS   | Windows |
  // | -------------------- | ------: | ------: |
  // |                      | ns/atom | ns/atom |
  // | rotate animation     |    2.49 |    6.12 |
  // | API usage            |    2.32 |    5.28 |
  // | register transaction |    3.90 |    7.74 |
  // | memcpy to GPU buffer |    0.54 |    2.02 |
  // | total                |    9.25 |   21.16 |
  //
  // | GPU-side contributor | macOS   | Windows |
  // | -------------------- | ------: | ------: |
  // |                      | ns/atom | ns/atom |
  // | PCIe transfer        |    0.00 |    1.59 |
  // | update BVH           |    1.69 |    7.33 |
  // | total                |    1.69 |    7.33 |
  
  // 100M address space size
  //
  // | Block Size | macOS     | Windows   |
  // | ---------- | --------: | --------: |
  // |            | s/address | s/address |
  // | 256        |  1.30E-12 |  1.86E-12 |
  // | 512        |  6.50E-13 |  9.90E-13 |
  // | 1024       |  3.30E-13 |  5.50E-13 |
  //
  // | Block Size | macOS     | Windows   |
  // | ---------- | --------: | --------: |
  // |            | ms        | ms        |
  // | 256        |     0.130 |     0.186 |
  // | 512        |     0.065 |     0.099 |
  // | 1024       |     0.033 |     0.055 |
  
  // GPU is reaching 78-80% PCIe utilization, with PCIe 3 x16 = 15.76 GB/s.
  // That means 1.61 ns/atom (0.1M atoms), 1.59 ns/atom (1M atoms) on the GPU
  // timeline.
  //
  // In performance calculations, assume "PCIe transfer" and "update BVH"
  // happen concurrently on the GPU timeline.
  func registerChanges() -> [Transaction] {
    func createModifiedBlockIDs() -> [UInt32] {
      var modifiedBlockIDs: [UInt32] = []
      for blockID in 0..<(addressSpaceSize / Self.blockSize) {
        // Reset blocksModified
        guard blocksModified[blockID] else {
          continue
        }
        blocksModified[blockID] = false
        
        modifiedBlockIDs.append(UInt32(blockID))
      }
      return modifiedBlockIDs
    }
    let modifiedBlockIDs = createModifiedBlockIDs()
    
    let taskSize: Int = 50_000 / Self.blockSize
    let taskCount = (modifiedBlockIDs.count + taskSize - 1) / taskSize
    
    func createChunks() -> [Transaction] {
      var output: [Transaction] = []
      for taskID in 0..<taskCount {
        let start = taskID * taskSize
        let end = min(start + taskSize, modifiedBlockIDs.count)
        
        let chunk = Transaction(blockCount: end - start)
        output.append(chunk)
      }
      return output
    }
    nonisolated(unsafe)
    let output = createChunks()
    
    nonisolated(unsafe)
    let safePositionsModified = self.positionsModified
    nonisolated(unsafe)
    let safePreviousOccupied = self.previousOccupied
    nonisolated(unsafe)
    let safeOccupied = self.occupied
    nonisolated(unsafe)
    let safePositions = self.positions
    DispatchQueue.concurrentPerform(iterations: taskCount) { taskID in
      let chunk = output[taskID]
      
      let start = taskID * taskSize
      let end = min(start + taskSize, modifiedBlockIDs.count)
      for i in start..<end {
        let blockID = modifiedBlockIDs[i]
        
        let startAtomID = blockID * UInt32(Self.blockSize)
        let endAtomID = startAtomID + UInt32(Self.blockSize)
        for atomID in startAtomID..<endAtomID {
          // Reset positionsModified
          guard safePositionsModified[Int(atomID)] else {
            continue
          }
          safePositionsModified[Int(atomID)] = false
          
          // Read occupied
          let atomPreviousOccupied = safePreviousOccupied[Int(atomID)]
          let atomOccupied = safeOccupied[Int(atomID)]
          
          // Save changes to previousOccupied
          safePreviousOccupied[Int(atomID)] = atomOccupied
          
          if !atomOccupied {
            if atomPreviousOccupied {
              chunk.removedIDs[Int(chunk.removedCount)] = atomID
              chunk.removedCount += 1
            }
          } else {
            // Read positions
            let position = safePositions[Int(atomID)]
            
            if atomPreviousOccupied {
              chunk.movedIDs[Int(chunk.movedCount)] = atomID
              chunk.movedPositions[Int(chunk.movedCount)] = position
              chunk.movedCount += 1
            } else {
              chunk.addedIDs[Int(chunk.addedCount)] = atomID
              chunk.addedPositions[Int(chunk.addedCount)] = position
              chunk.addedCount += 1
            }
          }
        }
      }
    }
    
    return output
  }
}
