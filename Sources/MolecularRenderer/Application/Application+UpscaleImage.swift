extension Application {
  private func fallbackUpscale() {
    device.commandQueue.withCommandList { commandList in
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(resources.descriptorHeap)
      #endif
      
      // Encode the compute command.
      commandList.withPipelineState(resources.upscaleShader) {
        // Bind the textures.
        #if os(macOS)
        let colorTexture = renderTarget.colorTextures[frameID % 2]
        let upscaledTexture = renderTarget.upscaledTextures[frameID % 2]
        commandList.mtlCommandEncoder
          .setTexture(colorTexture, index: 0)
        commandList.mtlCommandEncoder
          .setTexture(upscaledTexture, index: 1)
        #else
        commandList.setDescriptor(
          handleID: frameID % 2, index: 0)
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
  }
  
  private func createJitterOffset() -> SIMD2<Float> {
    var jitterOffsetDesc = JitterOffsetDescriptor()
    jitterOffsetDesc.index = frameID
    jitterOffsetDesc.upscaleFactor = renderTarget.upscaleFactor
    
    return JitterOffset.create(descriptor: jitterOffsetDesc)
  }
  
  public func upscale(image: Image) -> Image {
    guard renderTarget.upscaleFactor > 1 else {
      fatalError("Upscaling is not allowed.")
    }
    guard image.scaleFactor == 1 else {
      fatalError("Received image with incorrect scale factor.")
    }
    
    #if os(macOS)
    guard let upscaler else {
      fatalError("Upscaler was not present.")
    }
    
    if frameID == 0 {
      upscaler.scaler.reset = true
    } else {
      upscaler.scaler.reset = false
    }
    
    upscaler.scaler.colorTexture = renderTarget.colorTextures[frameID % 2]
    upscaler.scaler.depthTexture = renderTarget.depthTextures[frameID % 2]
    upscaler.scaler.motionTexture = renderTarget.motionTextures[frameID % 2]
    upscaler.scaler.outputTexture = renderTarget.upscaledTextures[frameID % 2]
    
    let jitterOffset = createJitterOffset()
    upscaler.scaler.jitterOffsetX = -jitterOffset[0]
    upscaler.scaler.jitterOffsetY = -jitterOffset[1]
    
    device.commandQueue.withCommandList { commandList in
      commandList.mtlCommandEncoder.endEncoding()
      
      upscaler.scaler.encode(commandBuffer: commandList.mtlCommandBuffer)
      
      commandList.mtlCommandEncoder =
      commandList.mtlCommandBuffer.makeComputeCommandEncoder()!
    }
    
    #else
    fallbackUpscale()
    #endif
    
    var output = Image()
    output.scaleFactor = renderTarget.upscaleFactor
    return output
  }
}
