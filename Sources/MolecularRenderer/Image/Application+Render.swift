import func Foundation.tan

#if os(Windows)
import SwiftCOM
import WinSDK
#endif

extension Application {
  private func readCrashBuffer() {
    if frameID >= 0 {
      let elementCount = BVHCounters.crashBufferSize / 4
      var output = [UInt32](repeating: .zero, count: elementCount)
      bvhBuilder.counters.crashBuffer.read(
        data: &output,
        inFlightFrameID: frameID % 3)
      
      // Current substitute for a proper crash decoding mechanism.
      // Should gate this under whether output[0] != 1.
      print("frame \(frameID):", output[0], output[1], output[2], output[3])
    }
  }
  
  private func writeCameraArgs() {
    var currentCameraArgs = CameraArgs()
    currentCameraArgs.position = (
      camera.position[0],
      camera.position[1],
      camera.position[2])
    currentCameraArgs.tangentFactor = tan(camera.fovAngleVertical / 2)
    currentCameraArgs.basis = camera.basis
    
    let previousCameraArgs =
    imageResources.previousCameraArgs ?? currentCameraArgs
    let cameraArgsList = [currentCameraArgs, previousCameraArgs]
    imageResources.cameraArgsBuffer.write(
      data: cameraArgsList,
      inFlightFrameID: frameID % 3)
    
    imageResources.previousCameraArgs = currentCameraArgs
  }
  
  private func createJitterOffset() -> SIMD2<Float> {
    guard imageResources.renderTarget.upscaleFactor > 1 else {
      return SIMD2<Float>.zero
    }
    
    var jitterOffsetDesc = JitterOffsetDescriptor()
    jitterOffsetDesc.index = frameID
    jitterOffsetDesc.upscaleFactor = imageResources.renderTarget.upscaleFactor
    
    return JitterOffset.create(descriptor: jitterOffsetDesc)
  }
  
  public func render() -> Image {
    readCrashBuffer()
    writeCameraArgs()
    
    // Create the render arguments.
    var renderArgs = RenderArgs()
    renderArgs.jitterOffset = createJitterOffset()
    renderArgs.frameSeed = UInt32.random(in: 0..<UInt32.max)
    
    device.commandQueue.withCommandList { commandList in
      #if os(Windows)
      // Bind the descriptor heap.
      commandList.setDescriptorHeap(descriptorHeap)
      
      // Dispatch the GPU commands to copy the PCIe data.
      imageResources.cameraArgsBuffer.copy(
        commandList: commandList,
        inFlightFrameID: frameID % 3)
      #endif
      
      #if os(Windows)
      bvhBuilder.computeUAVBarrier(commandList: commandList)
      #endif
    }
    
    /*
    device.commandQueue.withCommandList { commandList in
      // Encode the compute command.
      commandList.withPipelineState(resources.renderShader) {
        commandList.set32BitConstants(
          renderArgs, index: RenderShader.renderArgs)
        
        // Bind the camera args buffer.
        let cameraArgsBuffer = resources.cameraArgsBuffer
          .nativeBuffers[frameID % 3]
        commandList.setBuffer(
          cameraArgsBuffer, index: RenderShader.cameraArgs)
        
        // Bind the atom buffer.
        let atomBuffer = resources.atomsBuffer
          .nativeBuffers[frameID % 3]
        commandList.setBuffer(
          atomBuffer, index: RenderShader.atoms)
        
        // Bind the motion vectors buffer.
        #if os(macOS)
        let motionVectorsBuffer = resources.motionVectorsBuffer
          .nativeBuffers[frameID % 3]
        commandList.setBuffer(
          motionVectorsBuffer, index: RenderShader.motionVectors)
        #else
        commandList.setDescriptor(
          handleID: resources.motionVectorsBaseHandleID + frameID % 3,
          index: RenderShader.motionVectors)
        #endif
        
        // Bind the color texture.
        #if os(macOS)
        let colorTexture = renderTarget.colorTextures[frameID % 2]
        commandList.mtlCommandEncoder.setTexture(
          colorTexture, index: RenderShader.colorTexture)
        #else
        commandList.setDescriptor(
          handleID: frameID % 2, index: RenderShader.colorTexture)
        #endif
        
        // Bind the depth and motion textures.
        if renderTarget.upscaleFactor > 1 {
          #if os(macOS)
          let depthTexture = renderTarget.depthTextures[frameID % 2]
          let motionTexture = renderTarget.motionTextures[frameID % 2]
          commandList.mtlCommandEncoder.setTexture(
            depthTexture, index: RenderShader.depthTexture)
          commandList.mtlCommandEncoder.setTexture(
            motionTexture, index: RenderShader.motionTexture)
          #else
          commandList.setDescriptor(
            handleID: 2 + frameID % 2, index: RenderShader.depthTexture)
          commandList.setDescriptor(
            handleID: 4 + frameID % 2, index: RenderShader.motionTexture)
          #endif
        }
        
        // Determine the dispatch grid size.
        func createGroupCount32() -> SIMD3<UInt32> {
          var groupCount = renderTarget.intermediateSize(display: display)
          
          let groupSize = SIMD2<Int>(8, 8)
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
     */
    
    var output = Image()
    output.scaleFactor = 1
    return output
  }
}
