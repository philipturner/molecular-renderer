import Dispatch

// Temporary import for profiling CPU-side bottleneck.
import Foundation

extension BVHBuilder {
  // Reduction over all chunks of the transaction.
  private struct TransactionReduction {
    var totalRemoved: Int = .zero
    var totalMoved: Int = .zero
    var totalAdded: Int = .zero
    
    var removedPrefixSum: [UInt32] = []
    var movedPrefixSum: [UInt32] = []
    var addedPrefixSum: [UInt32] = []
    
    init(transaction: [Atoms.Transaction]) {
      for taskID in transaction.indices {
        let chunk = transaction[taskID]
        
        removedPrefixSum.append(UInt32(totalRemoved))
        movedPrefixSum.append(UInt32(totalMoved))
        addedPrefixSum.append(UInt32(totalAdded))
        
        totalRemoved += Int(chunk.removedCount)
        totalMoved += Int(chunk.movedCount)
        totalAdded += Int(chunk.addedCount)
      }
    }
  }
  
  // Upload the acceleration structure changes for every frame.
  func upload(
    transaction: [Atoms.Transaction],
    commandList: CommandList,
    inFlightFrameID: Int
  ) {
    
    let checkpoint0 = Date()
    let reduction = TransactionReduction(
      transaction: transaction)
    
    // Validate the sizes of the transaction components.
    let maxTransactionSize = AtomResources.maxTransactionSize
    guard reduction.totalRemoved <= maxTransactionSize else {
      fatalError("Removed atom count must not exceed \(maxTransactionSize).")
    }
    guard reduction.totalMoved + reduction.totalAdded <= maxTransactionSize else {
      fatalError(
        "Moved and added atom count must not exceed \(maxTransactionSize).")
    }
    
    // Write to the IDs buffer.
    let checkpoint1 = Date()
    do {
      #if os(macOS)
      nonisolated(unsafe)
      let buffer = atoms.transactionIDs.nativeBuffers[inFlightFrameID]
      #else
      nonisolated(unsafe)
      let buffer = atoms.transactionIDs.inputBuffers[inFlightFrameID]
      #endif
      
      for taskID in transaction.indices {
        let chunk = transaction[taskID]
        let removedPointer = UnsafeRawBufferPointer(
          start: chunk.removedIDs, count: Int(chunk.removedCount) * 4)
        let movedPointer = UnsafeRawBufferPointer(
          start: chunk.movedIDs, count: Int(chunk.movedCount) * 4)
        let addedPointer = UnsafeRawBufferPointer(
          start: chunk.addedIDs, count: Int(chunk.addedCount) * 4)
        
        let removedOffset = Int(reduction.removedPrefixSum[taskID])
        let movedOffset = Int(reduction.movedPrefixSum[taskID])
        let addedOffset = Int(reduction.addedPrefixSum[taskID])
        buffer.write(
          input: removedPointer,
          offset: (removedOffset) * 4)
        buffer.write(
          input: movedPointer,
          offset: (reduction.totalRemoved + movedOffset) * 4)
        buffer.write(
          input: addedPointer,
          offset: (reduction.totalRemoved + reduction.totalMoved + addedOffset) * 4)
      }
    }
    
    // Write to the atoms buffer.
    let checkpoint2 = Date()
    do {
      #if os(macOS)
      nonisolated(unsafe)
      let buffer = atoms.transactionAtoms.nativeBuffers[inFlightFrameID]
      #else
      nonisolated(unsafe)
      let buffer = atoms.transactionAtoms.inputBuffers[inFlightFrameID]
      #endif
      
      nonisolated(unsafe)
      let safeTransaction = transaction
      let taskCount = transaction.count
      DispatchQueue.concurrentPerform(iterations: taskCount) { taskID in
        let chunk = safeTransaction[taskID]
        let movedPointer = UnsafeRawBufferPointer(
          start: chunk.movedPositions, count: Int(chunk.movedCount) * 16)
        let addedPointer = UnsafeRawBufferPointer(
          start: chunk.addedPositions, count: Int(chunk.addedCount) * 16)
        
        let movedOffset = Int(reduction.movedPrefixSum[taskID])
        let addedOffset = Int(reduction.addedPrefixSum[taskID])
        buffer.write(
          input: movedPointer,
          offset: (movedOffset) * 16)
        buffer.write(
          input: addedPointer,
          offset: (reduction.totalMoved + addedOffset) * 16)
      }
    }
    let checkpoint3 = Date()
    
    func displayLatency(
      _ start: Date,
      _ end: Date,
      name: String
    ) {
      let latency = end.timeIntervalSince(start)
      let latencyMicroseconds = Int(latency * 1e6)
      print("upload.\(name):", latencyMicroseconds, "μs")
    }
    displayLatency(checkpoint0, checkpoint1, name: "latency01")
    displayLatency(checkpoint1, checkpoint2, name: "latency12")
    displayLatency(checkpoint2, checkpoint3, name: "latency23")
    
    #if os(Windows)
    // Dispatch the GPU commands to copy the PCIe data.
    do {
      let idsCount =
      reduction.totalRemoved + reduction.totalMoved + reduction.totalAdded
      atoms.transactionIDs.copy(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        range: 0..<(idsCount * 4))
      
      let atomsCount =
      reduction.totalMoved + reduction.totalAdded
      atoms.transactionAtoms.copy(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        range: 0..<(atomsCount * 16))
    }
    #endif
    
    // Set the transactionArgs.
    do {
      var transactionArgs = TransactionArgs()
      transactionArgs.removedCount = UInt32(reduction.totalRemoved)
      transactionArgs.movedCount = UInt32(reduction.totalMoved)
      transactionArgs.addedCount = UInt32(reduction.totalAdded)
      self.transactionArgs = transactionArgs
    }
  }
}
