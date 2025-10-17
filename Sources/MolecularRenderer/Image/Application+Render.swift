import func Foundation.tan
#if os(Windows)
import SwiftCOM
import WinSDK
#endif

extension Application {
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
  
  private func createRenderArgs() -> RenderArgs {
    let jitterOffset = createJitterOffset()
    
    var renderArgs = RenderArgs()
    renderArgs.jitterOffsetX = jitterOffset[0]
    renderArgs.jitterOffsetY = jitterOffset[1]
    renderArgs.frameSeed = UInt32.random(in: 0..<UInt32.max)
    renderArgs.upscaleFactor = imageResources.renderTarget.upscaleFactor
    
    if let secondaryRayCount = camera.secondaryRayCount {
      guard secondaryRayCount >= 3 else {
        fatalError("Secondary ray count must be at least 3.")
      }
      renderArgs.secondaryRayCount = UInt32(secondaryRayCount)
    } else {
      renderArgs.secondaryRayCount = UInt32(0)
    }
    
    if let criticalPixelCount = camera.criticalPixelCount {
      guard criticalPixelCount >= 1 else {
        fatalError("Critical pixel count must be at least 1.")
      }
      renderArgs.criticalPixelCount = criticalPixelCount
    } else {
      renderArgs.criticalPixelCount = Float(0)
    }
    
    return renderArgs
  }
  
  public func render() -> Image {
    checkCrashBuffer(frameID: frameID)
    checkExecutionTime(frameID: frameID)
    updateBVH(inFlightFrameID: frameID % 3)
    writeCameraArgs()
    
    device.commandQueue.withCommandList { commandList in
      #if os(Windows)
      try! commandList.d3d12CommandList.EndQuery(
        bvhBuilder.counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        2)
      
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
        
        let renderArgs = createRenderArgs()
        commandList.set32BitConstants(
          renderArgs, index: RenderShader.renderArgs)
        
        let cameraArgsBuffer = imageResources.cameraArgsBuffer
          .nativeBuffers[frameID % 3]
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
      
      try! commandList.d3d12CommandList.EndQuery(
        bvhBuilder.counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        3)
      
      let destinationBuffer = bvhBuilder.counters
        .queryDestinationBuffers[frameID % 3]
      try! commandList.d3d12CommandList.ResolveQueryData(
        bvhBuilder.counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        2,
        2,
        destinationBuffer.d3d12Resource,
        16)
      #endif
      
      #if os(macOS)
      nonisolated(unsafe)
      let selfReference = self
      let inFlightFrameID = frameID % 3
      commandList.mtlCommandBuffer.addCompletedHandler { commandBuffer in
        selfReference.bvhBuilder.counters.queue.sync {
          var executionTime = commandBuffer.gpuEndTime
          executionTime -= commandBuffer.gpuStartTime
          let latencyMicroseconds = Int(executionTime * 1e6)
          selfReference.bvhBuilder.counters
            .renderLatencies[inFlightFrameID] = latencyMicroseconds
        }
      }
      #endif
    }
    
    forgetIdleState(inFlightFrameID: frameID % 3)
    
    var output = Image()
    output.scaleFactor = 1
    return output
  }
}
