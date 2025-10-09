extension Application {
  // Will eventually remove the public modifier and automatically invoke this
  // inside 'application.render()'.
  public func updateBVH(inFlightFrameID: Int) {
    let transaction = atoms.registerChanges()
    
    device.commandQueue.withCommandList { commandList in
      bvhBuilder.purgeResources(commandList: commandList)
      bvhBuilder.upload(
        transaction: transaction,
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
    }
  }
  
  // Invoke this during 'application.render()', at the very end.
  public func forgetIdleState(inFlightFrameID: Int) {
    // Encode the command to purge the motion vectors.
    
    // Delete the transactionArgs state variable.
    bvhBuilder.transactionArgs = nil
  }
}
