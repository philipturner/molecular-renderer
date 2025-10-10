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
        dataBuffer: bvhBuilder.atomResources.relativeOffsets1)
      bvhBuilder.counters.crashBuffer.download(
        commandList: commandList,
        inFlightFrameID: 0)
    }
    device.commandQueue.flush()
    
    // var output = [SIMD4<UInt16>](repeating: .zero, count: 50000)
    // bvhBuilder.counters.crashBuffer.read(
    //   data: &output,
    //   inFlightFrameID: 0)
    
    // TODO: Archive this code in the checksum GitHub gist.
    
    // Gather the number of atoms with 1, 2, 4, 8 references.
    // var count0: Int = .zero
    // var count1: Int = .zero
    // var count2: Int = .zero
    // var count4: Int = .zero
    //for atomID in 0..<8631 {
      // let counters = output[atomID]
      // let existsMask = counters .!= SIMD4<UInt16>(repeating: UInt16.max)
      // var popcountMask: SIMD4<UInt16> = .zero
      // popcountMask.replace(
      //   with: SIMD4<UInt16>(repeating: 1),
      //   where: existsMask)
      
      // let count = popcountMask.wrappedSum()
      // switch count {
      // case 0:
      //   count0 += 1
      // case 1:
      //   count1 += 1
      // case 2:
      //   count2 += 1
      // case 4:
      //   count4 += 1
      // default:
      //   fatalError("Unexpected count: \(count)")
      // }
    //}
    
    // print(output[0])
    // print(output[1])
    // print(output[8000])
    // print(output[9000])
    
    // print()
    // print(count0)
    // print(count1)
    // print(count2)
    // print(count4)
  }
}
