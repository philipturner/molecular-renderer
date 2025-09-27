extension Application {
  // NOTE: When the API structure changes, this function signature will
  // become 'render() -> Image'.
  public func render() {
    let transaction = atoms.registerChanges()
    resources.transactionTracker.register(transaction: transaction)
    let atoms = resources.transactionTracker.compactedAtoms()
    
    // Write the atoms to the GPU buffer.
    let inFlightFrameID = frameID % 3
    resources.atomBuffer.write(
      atoms: atoms,
      inFlightFrameID: inFlightFrameID)
    
    // Retrieve the front buffer.
    let frontBufferID = frameID % 2
    let frontBuffer = renderTarget.colorTextures[frontBufferID]
    
    device.commandQueue.withCommandList { commandList in
      #if os(Windows)
      resources.atomBuffer.copy(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      #endif
      
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(resources.descriptorHeap)
      #endif
      
      // Encode the compute command.
      commandList.withPipelineState(resources.shader) {
        // Bind the texture.
        #if os(macOS)
        commandList.mtlCommandEncoder
          .setTexture(frontBuffer, index: 0)
        #else
        commandList.setDescriptor(
          handleID: frontBufferID, index: 0)
        #endif
        
        // Bind the atom buffer.
        let nativeBuffer = resources.atomBuffer.nativeBuffers[inFlightFrameID]
        commandList.setBuffer(nativeBuffer, index: 1)
        
        // Bind the constant arguments.
        struct ConstantArgs {
          var atomCount: UInt32
          var frameSeed: UInt32
        }
        let constantArgs = ConstantArgs(
          atomCount: UInt32(atoms.count),
          frameSeed: .random(in: 0..<UInt32.max))
        commandList.set32BitConstants(constantArgs, index: 2)
        
        // Determine the dispatch grid size.
        let groupSize = SIMD2<Int>(8, 8)
        
        var groupCount = display.frameBufferSize
        groupCount &+= groupSize &- 1
        groupCount /= groupSize
        
        let groupCount32 = SIMD3<UInt32>(
          UInt32(groupCount[0]),
          UInt32(groupCount[1]),
          UInt32(1))
        commandList.dispatch(groups: groupCount32)
      }
    }
  }
}
