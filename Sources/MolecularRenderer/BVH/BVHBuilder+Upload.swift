import Dispatch

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
    
    // TODO: Specify the benchmark conditions so we can preserve these
    // stats in the future, as justification for the design choice.
    
    // Serial copying of IDs and positions
    //
    // macOS:
    //   single-threaded: 88, 351 -> 461 μs
    //   multi-threaded: 77, 215 -> 285 μs
    //
    // Windows:
    //   single-threaded: 354, 1256 -> 1626 μs
    //   multi-threaded: 345, 1262 -> 1678 μs
    
    // Concurrent / simultaneous copying of IDs and positions
    //
    // macOS:
    //   single-threaded:
    //   multi-threaded:
    //
    // Windows:
    //   single-threaded: 1623 μs
    //   multi-threaded: 1657 μs
    
    #if os(macOS)
    nonisolated(unsafe)
    let idsBuffer = atoms.transactionIDs.nativeBuffers[inFlightFrameID]
    nonisolated(unsafe)
    let atomsBuffer = atoms.transactionAtoms.nativeBuffers[inFlightFrameID]
    #else
    nonisolated(unsafe)
    let idsBuffer = atoms.transactionIDs.inputBuffers[inFlightFrameID]
    nonisolated(unsafe)
    let atomsBuffer = atoms.transactionAtoms.inputBuffers[inFlightFrameID]
    #endif
    
    nonisolated(unsafe)
    let safeTransaction = transaction
    let taskCount = transaction.count
    // DispatchQueue.concurrentPerform(iterations: taskCount) { taskID in
    for taskID in 0..<taskCount {
      let chunk = safeTransaction[taskID]
      let removedOffset = Int(reduction.removedPrefixSum[taskID])
      let movedOffset = Int(reduction.movedPrefixSum[taskID])
      let addedOffset = Int(reduction.addedPrefixSum[taskID])
      
      let removedIDsPointer = UnsafeRawBufferPointer(
        start: chunk.removedIDs, count: Int(chunk.removedCount) * 4)
      let movedIDsPointer = UnsafeRawBufferPointer(
        start: chunk.movedIDs, count: Int(chunk.movedCount) * 4)
      let addedIDsPointer = UnsafeRawBufferPointer(
        start: chunk.addedIDs, count: Int(chunk.addedCount) * 4)
      idsBuffer.write(
        input: removedIDsPointer,
        offset: (removedOffset) * 4)
      idsBuffer.write(
        input: movedIDsPointer,
        offset: (reduction.totalRemoved + movedOffset) * 4)
      idsBuffer.write(
        input: addedIDsPointer,
        offset: (reduction.totalRemoved + reduction.totalMoved + addedOffset) * 4)
      
      let movedPositionsPointer = UnsafeRawBufferPointer(
        start: chunk.movedPositions, count: Int(chunk.movedCount) * 16)
      let addedPositionsPointer = UnsafeRawBufferPointer(
        start: chunk.addedPositions, count: Int(chunk.addedCount) * 16)
      atomsBuffer.write(
        input: movedPositionsPointer,
        offset: (movedOffset) * 16)
      atomsBuffer.write(
        input: addedPositionsPointer,
        offset: (reduction.totalMoved + addedOffset) * 16)
    }
    
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
