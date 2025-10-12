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
      
      bvhBuilder.purgeResources(commandList: commandList)
      bvhBuilder.setupGeneralCounters(commandList: commandList)
      bvhBuilder.upload(
        transaction: transaction,
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      
      bvhBuilder.removeProcess1(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      bvhBuilder.addProcess1(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      
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
      bvhBuilder.resetAtomicCounters(
        commandList: commandList)
      
      #if os(Windows)
      bvhBuilder.computeUAVBarrier(commandList: commandList)
      #endif
    }
    
    // Delete the transactionArgs state variable.
    bvhBuilder.transactionArgs = nil
  }
  
  public func runDiagnostic() {
    device.commandQueue.withCommandList { commandList in
      bvhBuilder.debugDiagnostic(
        commandList: commandList,
        dataBuffer: bvhBuilder.counters.generalCounters)
      bvhBuilder.counters.diagnosticBuffer.download(
        commandList: commandList,
        inFlightFrameID: 0)
    }
    device.commandQueue.flush()
    
    var output = [UInt32](repeating: .zero, count: 10)
    bvhBuilder.counters.diagnosticBuffer.read(
      data: &output,
      inFlightFrameID: 0)
    
    for i in 0..<10 {
      print(output[i])
    }
  }
}
