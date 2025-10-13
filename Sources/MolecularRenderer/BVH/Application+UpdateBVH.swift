extension Application {
  // Will eventually remove the public modifier and automatically invoke this
  // inside 'application.render()'.
  public func updateBVH(inFlightFrameID: Int) {
    let transaction = atoms.registerChanges()
    
    // Dispatch this in a separate command list, increasing the chance the
    // GPU gets occupied with work earlier in the frame.
    device.commandQueue.withCommandList { commandList in
      bvhBuilder.upload(
        transaction: transaction,
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
    }
    
    // TODO: Time how long it takes to encode this command list on macOS.
    // Perhaps we should also split up the commands for purging buffers, but
    // that ought to be justified by profiling data before taking any action.
    device.commandQueue.withCommandList { commandList in
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(descriptorHeap)
      #endif
      
      bvhBuilder.purgeResources(commandList: commandList)
      bvhBuilder.setupGeneralCounters(commandList: commandList)
      
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
  
  public func runDiagnostic() {
    device.commandQueue.withCommandList { commandList in
      bvhBuilder.debugDiagnostic(
        commandList: commandList,
        dataBuffer: bvhBuilder.voxels.sparse.assignedVoxelCoords)
      bvhBuilder.counters.diagnosticBuffer.download(
        commandList: commandList,
        inFlightFrameID: 0)
    }
    device.commandQueue.flush()
    
    var output = [UInt32](repeating: .zero, count: 3616)
    bvhBuilder.counters.diagnosticBuffer.read(
      data: &output,
      inFlightFrameID: 0)
    
    let readSlotIDs: [Int] = [
      0, 1, 2, 3, 4, 5, 6,
      118, 119, 120, 121, 122, 123,
      182, 183, 184, 185, 186,
    ]
    
    for slotID in readSlotIDs {
      let outputValue = output[slotID]
      print(slotID, outputValue)
    }
  }
}
