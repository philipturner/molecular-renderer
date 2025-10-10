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
    }
    
    // Delete the transactionArgs state variable.
    bvhBuilder.transactionArgs = nil
  }
  
  public func runDiagnostic() {
    device.commandQueue.withCommandList { commandList in
      bvhBuilder.debugDiagnostic(
        commandList: commandList,
        dataBuffer: bvhBuilder.voxelResources.atomicCounters)
      bvhBuilder.counters.crashBuffer.download(
        commandList: commandList,
        inFlightFrameID: 0)
    }
    device.commandQueue.flush()
    
    // Implement a robust checksum of the atomic counters. Then, implement the
    // reordering optimization.
    var output = [SIMD8<UInt32>](repeating: .zero, count: 4096)
    bvhBuilder.counters.crashBuffer.read(
      data: &output,
      inFlightFrameID: 0)
    
    // example addresses to mess up:
    // 2473 (occupied)
    // 2475 (unoccupied)
    
    var xorHash: SIMD4<UInt32> = .zero
    var rotateHash: SIMD4<UInt32> = .zero
    var addressRotateHash: UInt32 = .zero
    var referenceSum: UInt32 = .zero
    var voxelSum: UInt32 = .zero
    
    for z in 0..<16 {
      for y in 0..<16 {
        for x in 0..<16 {
          let address = z * 16 * 16 + y * 16 + x
          let counters = output[address]
          guard counters.wrappedSum() > 0 else {
            continue
          }
          
          
        }
      }
    }
    
  }
}
