extension Application {
  // Will eventually remove the public modifier and automatically invoke this
  // inside 'application.render()'.
  public func updateBVH(inFlightFrameID: Int) {
    let transaction = atoms.registerChanges()
    
    // device.commandQueue.withCommandList { commandList in
    //   bvhBuilder.purgeResources(commandList: commandList)
    //   bvhBuilder.upload(
    //     transaction: transaction,
    //     commandList: commandList,
    //     inFlightFrameID: inFlightFrameID)
    // }
    
    bvhBuilder.upload(
      transaction: transaction,
      device: device,
      inFlightFrameID: inFlightFrameID)
  }
}
