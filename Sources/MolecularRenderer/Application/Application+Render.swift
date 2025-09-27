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
          var atomCount: UInt32 = .zero
          var frameSeed: UInt32 = .zero
          var tangentFactor: Float = .zero
          // var cameraPosition: SIMD3<Float> = .zero
          
          // var cameraBasis: (
          //   SIMD3<Float>,
          //   SIMD3<Float>,
          //   SIMD3<Float>
          // ) = (.zero, .zero, .zero)
        }
        var constantArgs = ConstantArgs()
        constantArgs.atomCount = UInt32(atoms.count)
        constantArgs.frameSeed = UInt32.random(in: 0..<UInt32.max)
        constantArgs.tangentFactor = tan(Float.pi / 180 * 20)
        // constantArgs.cameraPosition = SIMD3(0, 0, 1)
        // constantArgs.cameraBasis = (
        //   SIMD3(1, 0, 0),
        //   SIMD3(0, -1, 0),
        //   SIMD3(0, 0, 1))
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
    
    return Image()
  }
}
