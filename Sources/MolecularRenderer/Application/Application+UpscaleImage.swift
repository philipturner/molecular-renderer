extension Application {
  public func upscale(image: Image) -> Image {
    guard renderTarget.upscaleFactor > 1 else {
      fatalError("Upscaling is not allowed.")
    }
    guard image.scaleFactor == 1 else {
      fatalError("Received image with incorrect scale factor.")
    }
    
    device.commandQueue.withCommandList { commandList in
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(resources.descriptorHeap)
      #endif
      
      // Encode the compute command.
      commandList.withPipelineState(resources.upscaleShader) {
        // Bind the textures.
        #if os(macOS)
        let colorTexture = renderTarget.motionTextures[frameID % 2]
        let upscaledTexture = renderTarget.upscaledTextures[frameID % 2]
        commandList.mtlCommandEncoder
          .setTexture(colorTexture, index: 0)
        commandList.mtlCommandEncoder
          .setTexture(upscaledTexture, index: 1)
        #else
        commandList.setDescriptor(
          handleID: 4 + frameID % 2, index: 0)
        commandList.setDescriptor(
          handleID: 6 + frameID % 2, index: 1)
        #endif
        
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
    
    var output = Image()
    output.scaleFactor = renderTarget.upscaleFactor
    return output
  }
}
