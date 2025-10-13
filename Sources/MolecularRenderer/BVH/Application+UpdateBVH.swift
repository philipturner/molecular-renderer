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
  #if os(Windows)
  nonisolated(unsafe)
  private static var uploadBuffer: Buffer?
  #endif
  
  public func uploadDebugInput(
    _ inputData: [UInt32]
  ) {
    func copyDestinationBuffer() -> Buffer {
      bvhBuilder.voxels.sparse.assignedVoxelCoords
    }
    
    
    #if os(Windows)
    device.commandQueue.withCommandList { commandList in
      
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
      
      print("checkpoint 1")
      device.commandQueue.flush()
      print("checkpoint 2")
      inputData.withUnsafeBytes { bufferPointer in
        inputBuffer.write(input: bufferPointer)
      }
      print("checkpoint 3")
      Self.uploadBuffer = inputBuffer
      
      print("checkpoint 4")
      commandList.upload(
        inputBuffer: inputBuffer,
        nativeBuffer: nativeBuffer)
      print("checkpoint 5")
    }
    print("checkpoint 6")
    #endif
  }
  
  public func downloadDebugOutput(
    _ outputData: inout [UInt32]
  ) {
    func copySourceBuffer() -> Buffer {
      bvhBuilder.voxels.sparse.vacantSlotIDs
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
  
  public func downloadDebugOutput2(
    _ outputData: inout [UInt32]
  ) {
    func copySourceBuffer() -> Buffer {
      bvhBuilder.counters.general
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
