extension Application {
  // Will eventually remove the public modifier and automatically invoke this
  // inside 'application.render()'.
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
  
  // Invoke this during 'application.render()', at the very end.
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

extension Application {
  public func uploadDebugInput(
    _ inputData: [UInt32]
  ) {
    func copyDestinationBuffer() -> Buffer {
      bvhBuilder.voxels.sparse.assignedVoxelCoords
    }
    
    #if os(macOS)
    let inputBuffer = copyDestinationBuffer()
    #else
    let nativeBuffer = copyDestinationBuffer()
    
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = nativeBuffer.size
    bufferDesc.type = .input
    let inputBuffer = Buffer(descriptor: bufferDesc)
    #endif
    
    device.commandQueue.flush()
    inputData.withUnsafeBytes { bufferPointer in
      inputBuffer.write(input: bufferPointer)
    }
    
    #if os(Windows)
    device.commandQueue.withCommandList { commandList in
      commandList.upload(
        inputBuffer: inputBuffer,
        nativeBuffer: nativeBuffer)
    }
    #endif
  }
  
  public func downloadDebugOutput(
    _ outputData: inout [UInt32]
  ) {
    func createOutputData() -> [UInt32] {
      fatalError("Not implemented.")
    }
    func copySourceBuffer() -> Buffer {
      bvhBuilder.voxels.sparse.assignedVoxelCoords
    }
    
    #if os(macOS)
    let outputBuffer = copySourceBuffer()
    #else
    let nativeBuffer = copySourceBuffer()
    
    var bufferDesc = BufferDescriptor()
    bufferDesc.device = device
    bufferDesc.size = nativeBuffer.size
    bufferDesc.type = .output
    let outputBuffer = Buffer(descriptor: bufferDesc)
    #endif
    
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
