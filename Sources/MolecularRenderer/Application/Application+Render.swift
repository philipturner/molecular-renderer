import func Foundation.tan

extension Application {
  public func render() -> Image {
    let transaction = atoms.registerChanges()
    resources.transactionTracker.register(transaction: transaction)
    let atoms = resources.transactionTracker.compactedAtoms()
    
    // Write the atoms to the GPU buffer.
    let inFlightFrameID = frameID % 3
    resources.atomBuffer.write(
      atoms: atoms,
      inFlightFrameID: inFlightFrameID)
    
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
      commandList.withPipelineState(resources.renderShader) {
        // Bind the texture.
        #if os(macOS)
        let colorTexture = renderTarget.colorTextures[frameID % 2]
        commandList.mtlCommandEncoder
          .setTexture(colorTexture, index: 0)
        #else
        commandList.setDescriptor(
          handleID: frameID % 2, index: 0)
        #endif
        
        // Bind the atom buffer.
        let nativeBuffer = resources.atomBuffer.nativeBuffers[inFlightFrameID]
        commandList.setBuffer(nativeBuffer, index: 1)
        
        // Bind the constant arguments.
        var constantArgs = ConstantArgs()
        constantArgs.atomCount = UInt32(atoms.count)
        constantArgs.frameSeed = UInt32.random(in: 0..<UInt32.max)
        constantArgs.tangentFactor = tan(camera.fovAngleVertical / 2)
        constantArgs.cameraPosition = camera.position
        constantArgs.cameraBasis = camera.basis
        commandList.set32BitConstants(constantArgs, index: 2)
        
        // Determine the dispatch grid size.
        func createGroupCount32() -> SIMD3<UInt32> {
          let groupSize = SIMD2<Int>(8, 8)
          
          var groupCount = display.frameBufferSize
          groupCount &+= groupSize &- 1
          groupCount /= groupSize
          
          return SIMD3<UInt32>(
            UInt32(groupCount[0]),
            UInt32(groupCount[1]),
            UInt32(1))
        }
        commandList.dispatch(groups: createGroupCount32())
      }
    }
    
    return Image()
  }
}
