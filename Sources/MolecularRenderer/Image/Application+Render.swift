import func Foundation.tan
#if os(Windows)
import SwiftCOM
import WinSDK
#endif

private typealias Basis = (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
private func transpose(basis: Basis) -> Basis {
  let output0 = SIMD3(
    basis.0[0], basis.1[0], basis.2[0])
  let output1 = SIMD3(
    basis.0[1], basis.1[1], basis.2[1])
  let output2 = SIMD3(
    basis.0[2], basis.1[2], basis.2[2])
  return (output0, output1, output2)
}

extension Application {
  private func validateCameraArgs() {
    func check(basis: Basis) {
      let dotProduct00 = (basis.0 * basis.0).sum()
      let dotProduct11 = (basis.1 * basis.1).sum()
      let dotProduct22 = (basis.2 * basis.2).sum()
      let axisLengthsSquared = [dotProduct00, dotProduct11, dotProduct22]
      
      for dotProduct in axisLengthsSquared {
        let actual = dotProduct
        let expected: Float = 1.000
        let difference = actual - expected
        guard difference.magnitude < 0.001 else {
          fatalError("camera.basis was invalid.")
        }
      }
      
      let dotProduct01 = (basis.0 * basis.1).sum()
      let dotProduct12 = (basis.1 * basis.2).sum()
      let dotProduct20 = (basis.2 * basis.0).sum()
      let axisSimilarities = [dotProduct01, dotProduct12, dotProduct20]
      
      for dotProduct in axisSimilarities {
        let actual = dotProduct
        let expected: Float = 0.000
        let difference = actual - expected
        guard difference.magnitude < 0.001 else {
          fatalError("camera.basis was invalid.")
        }
      }
    }
    
    check(basis: camera.basis)
    
    let transposed = transpose(basis: camera.basis)
    check(basis: transposed)
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
  
  private func createRenderArgs() -> RenderArgs {
    var renderArgs = RenderArgs()
    let screenDimensions = imageResources.renderTarget
      .intermediateSize(display: display)
    renderArgs.screenDimensions = SIMD2<UInt32>(
      truncatingIfNeeded: screenDimensions)
    renderArgs.jitterOffset = createJitterOffset()
    renderArgs.frameSeed = UInt32.random(in: 0..<UInt32.max)
    renderArgs.upscaleFactor = imageResources.renderTarget.upscaleFactor
    
    if let secondaryRayCount = camera.secondaryRayCount {
      guard secondaryRayCount >= 3 else {
        fatalError("Secondary ray count must be at least 3.")
      }
      renderArgs.secondaryRayCount = Float(secondaryRayCount)
    } else {
      renderArgs.secondaryRayCount = Float(0)
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
    guard frameID >= 0 else {
      fatalError("Not allowed to call render here.")
    }
    
    checkCrashBuffer(frameID: frameID)
    checkExecutionTime(frameID: frameID)
    updateBVH(inFlightFrameID: frameID % 3)
    validateCameraArgs()
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
          bvhBuilder.voxels.group.occupiedMarks8,
          index: RenderShader.voxelGroup8OccupiedMarks)
        commandList.setBuffer(
          bvhBuilder.voxels.group.occupiedMarks32,
          index: RenderShader.voxelGroup32OccupiedMarks)
        commandList.setBuffer(
          bvhBuilder.voxels.dense.assignedSlotIDs,
          index: RenderShader.assignedSlotIDs)
        commandList.setBuffer(
          bvhBuilder.voxels.sparse.headers,
          index: RenderShader.headers)
        commandList.setBuffer(
          bvhBuilder.voxels.sparse.references32,
          index: RenderShader.references32)
        
        // Bind the 16-bit references.
        #if os(macOS)
        commandList.setBuffer(
          bvhBuilder.voxels.sparse.references16,
          index: RenderShader.references16)
        #else
        if let handleID = bvhBuilder.voxels.sparse.references16HandleID {
          commandList.setDescriptor(
            handleID: handleID,
            index: RenderShader.references16)
        } else {
          commandList.setBuffer(
            bvhBuilder.voxels.sparse.references16,
            index: RenderShader.references16)
        }
        #endif
        
        // Bind the color texture.
        if !display.isOffline {
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
        } else {
          #if os(macOS)
          let colorBuffer = imageResources.renderTarget.nativeBuffer!
          commandList.setBuffer(
            colorBuffer, index: RenderShader.colorTexture)
          #else
          commandList.setDescriptor(
            handleID: 0,
            index: RenderShader.colorTexture)
          #endif
        }
        
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
      
      if display.isOffline {
        let nativeBuffer = imageResources.renderTarget.nativeBuffer!
        let outputBuffer = imageResources.renderTarget.outputBuffer!
        commandList.download(
          nativeBuffer: nativeBuffer,
          outputBuffer: outputBuffer)
      }
      
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
    
    if display.isOffline {
      frameID += 1
    }
    
    var output = Image()
    if display.isOffline {
      device.commandQueue.flush()
      
      #if os(macOS)
      let buffer = imageResources.renderTarget.nativeBuffer!
      #else
      let buffer = imageResources.renderTarget.outputBuffer!
      #endif
      
      let frameBufferSize = display.frameBufferSize
      let pixelCount = frameBufferSize[0] * frameBufferSize[1]
      var data = [SIMD4<Float16>](repeating: .zero, count: pixelCount)
      data.withUnsafeMutableBytes { bufferPointer in
        buffer.read(output: bufferPointer)
      }
      
      output.pixels = data
    }
    output.scaleFactor = 1
    return output
  }
}
