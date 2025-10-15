extension Application {
  // TODO: Before finishing the acceleration structure PR, remove the public
  // modifier for this.
  public func updateBVH(inFlightFrameID: Int) {
    let transaction = atoms.registerChanges()
    
    device.commandQueue.withCommandList { commandList in
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(descriptorHeap)
      #endif
      
      bvhBuilder.purgeResources(
        commandList: commandList)
      bvhBuilder.setupGeneralCounters(
        commandList: commandList)
      bvhBuilder.upload(
        transaction: transaction,
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      
      // Encode the remove process.
      bvhBuilder.removeProcess1(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      bvhBuilder.removeProcess2(
        commandList: commandList)
      bvhBuilder.removeProcess3(
        commandList: commandList)
      bvhBuilder.removeProcess4(
        commandList: commandList)
      
      // Encode the add process.
      bvhBuilder.addProcess1(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      bvhBuilder.addProcess2(
        commandList: commandList)
      bvhBuilder.addProcess3(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      
      // Encode the rebuild process.
      bvhBuilder.rebuildProcess1(
        commandList: commandList)
      bvhBuilder.rebuildProcess2(
        commandList: commandList)
      
      bvhBuilder.counters.crashBuffer.download(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
    }
  }
  
  // TODO: Before finishing the acceleration structure PR, remove the public
  // modifier for this.
  public func forgetIdleState(inFlightFrameID: Int) {
    device.commandQueue.withCommandList { commandList in
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(descriptorHeap)
      #endif
      
      bvhBuilder.resetMotionVectors(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      bvhBuilder.resetVoxelMarks(
        commandList: commandList)
      
      #if os(Windows)
      bvhBuilder.computeUAVBarrier(commandList: commandList)
      #endif
    }
    
    // Delete the transactionArgs state variable.
    bvhBuilder.transactionArgs = nil
  }
}

// TODO: Before finishing the acceleration structure PR, remove these debugging
// utilities from the code base.
extension Application {
  // Circumvent a flaky crash by holding a reference to the buffer while the
  // command list executes. Do not abuse this by calling any of the 'Debug'
  // functions more than once in a single program execution.
  nonisolated(unsafe)
  private static var downloadBuffers: [Buffer] = []
  
  public func downloadGeneralCounters() -> [UInt32] {
    func copySourceBuffer() -> Buffer {
      bvhBuilder.counters.general
    }
    
    var output = [UInt32](repeating: .zero, count: 10)
    downloadDebugOutput(
      &output, copySourceBuffer: copySourceBuffer())
    return output
  }
  
  public func downloadAssignedSlotIDs() -> [UInt32] {
    func copySourceBuffer() -> Buffer {
      bvhBuilder.voxels.dense.assignedSlotIDs
    }
    
    var output = [UInt32](repeating: .zero, count: 4096)
    downloadDebugOutput(
      &output, copySourceBuffer: copySourceBuffer())
    return output
  }
  
  public func downloadMemorySlots() -> [UInt32] {
    func copySourceBuffer() -> Buffer {
      bvhBuilder.voxels.sparse.memorySlots
    }
    
    var arraySize = bvhBuilder.voxels.memorySlotCount
    arraySize *= MemorySlot.totalSize
    arraySize /= 4
    
    var output = [UInt32](repeating: .zero, count: arraySize)
    downloadDebugOutput(
      &output, copySourceBuffer: copySourceBuffer())
    return output
  }
  
  public func downloadRebuiltVoxelCoords() -> [UInt32] {
    func copySourceBuffer() -> Buffer {
      bvhBuilder.voxels.sparse.rebuiltVoxelCoords
    }
    
    let arraySize = bvhBuilder.voxels.memorySlotCount
    
    var output = [UInt32](repeating: .zero, count: arraySize)
    downloadDebugOutput(
      &output, copySourceBuffer: copySourceBuffer())
    return output
  }
  
  private func downloadDebugOutput<T>(
    _ outputData: inout [T],
    copySourceBuffer: Buffer
  ) {
    #if os(macOS)
    let outputBuffer = copySourceBuffer
    #else
    let nativeBuffer = copySourceBuffer

    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = nativeBuffer.size
    bufferDesc.type = .output
    let outputBuffer = Buffer(descriptor: bufferDesc)
    #endif
    Self.downloadBuffers.append(outputBuffer)

    #if os(Windows)
    device.commandQueue.withCommandList { commandList in
      commandList.download(
        nativeBuffer: nativeBuffer,
        outputBuffer: outputBuffer)
    }
    #endif
    device.commandQueue.flush()

    outputData.withUnsafeMutableBytes { bufferPointer in
      outputBuffer.read(output: bufferPointer)
    }
  }
}
