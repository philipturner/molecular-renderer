import func Foundation.tan

#if os(Windows)
import SwiftCOM
import WinSDK
#endif

extension Application {
  private func readCrashBuffer() {
    if frameID >= 3 {
      let elementCount = CounterResources.crashBufferSize / 4
      var output = [UInt32](repeating: .zero, count: elementCount)
      bvhBuilder.counters.crashBuffer.read(
        data: &output,
        inFlightFrameID: frameID % 3)
      
      if output[0] != 1 {
        var crashInfoDesc = CrashInfoDescriptor()
        crashInfoDesc.bufferContents = output
        crashInfoDesc.clockFrames = clock.frames
        crashInfoDesc.displayFrameRate = display.frameRate
        crashInfoDesc.frameID = frameID
        crashInfoDesc.memorySlotCount = bvhBuilder.voxels.memorySlotCount
        crashInfoDesc.worldDimension = bvhBuilder.voxels.worldDimension
        let crashInfo = CrashInfo(descriptor: crashInfoDesc)
        
        fatalError(crashInfo.message)
      }
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
    updateBVH(inFlightFrameID: frameID % 3)
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
      
      // Encode the compute command.
      commandList.withPipelineState(imageResources.renderShader) {
        bvhBuilder.counters.crashBuffer.setBufferBindings(
          commandList: commandList)
        
        let cameraArgsBuffer = imageResources.cameraArgsBuffer
          .nativeBuffers[frameID % 3]
        commandList.set32BitConstants(
          renderArgs, index: RenderShader.renderArgs)
        commandList.setBuffer(
          cameraArgsBuffer, index: RenderShader.cameraArgs)
        commandList.setBuffer(
          bvhBuilder.atoms.atoms, index: RenderShader.atoms)
        
        // Bind the motion vectors.
        #if os(macOS)
        commandList.setBuffer(
          bvhBuilder.atoms.motionVectors,
          index: RenderShader.motionVectors)
        #else
        commandList.setDescriptor(
          handleID: bvhBuilder.atoms.motionVectorsHandleID,
          index: RenderShader.motionVectors)
        #endif
        
        commandList.setBuffer(
          bvhBuilder.voxels.group.occupiedMarks,
          index: RenderShader.voxelGroupOccupiedMarks)
        commandList.setBuffer(
          bvhBuilder.voxels.dense.assignedSlotIDs,
          index: RenderShader.assignedSlotIDs)
        commandList.setBuffer(
          bvhBuilder.voxels.sparse.memorySlots,
          index: RenderShader.memorySlots32)
        #if os(macOS)
        commandList.setBuffer(
          bvhBuilder.voxels.sparse.memorySlots,
          index: RenderShader.memorySlots16)
        #else
        commandList.setDescriptor(
          handleID: bvhBuilder.voxels.sparse.memorySlotsHandleID,
          index: RenderShader.memorySlots16)
        #endif
        
        // Bind the color texture.
        #if os(macOS)
        let colorTexture = imageResources.renderTarget
          .colorTextures[frameID % 2]
        commandList.mtlCommandEncoder.setTexture(
          colorTexture, index: RenderShader.colorTexture)
        #else
        commandList.setDescriptor(
          handleID: frameID % 2,
          index: RenderShader.colorTexture)
        #endif
        
        // Bind the depth and motion textures.
        if imageResources.renderTarget.upscaleFactor > 1 {
          #if os(macOS)
          let depthTexture = imageResources.renderTarget
            .depthTextures[frameID % 2]
          let motionTexture = imageResources.renderTarget
            .motionTextures[frameID % 2]
          commandList.mtlCommandEncoder.setTexture(
            depthTexture, index: RenderShader.depthTexture)
          commandList.mtlCommandEncoder.setTexture(
            motionTexture, index: RenderShader.motionTexture)
          #else
          commandList.setDescriptor(
            handleID: 2 + frameID % 2,
            index: RenderShader.depthTexture)
          commandList.setDescriptor(
            handleID: 4 + frameID % 2,
            index: RenderShader.motionTexture)
          #endif
        }
        
        func createGroupCount32() -> SIMD3<UInt32> {
          var groupCount = imageResources.renderTarget
            .intermediateSize(display: display)
          
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
      
      #if os(Windows)
      bvhBuilder.computeUAVBarrier(commandList: commandList)
      #endif
    }
    
    forgetIdleState(inFlightFrameID: frameID % 3)
    
    var output = Image()
    output.scaleFactor = 1
    return output
  }
}
